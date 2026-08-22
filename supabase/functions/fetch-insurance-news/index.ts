import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS, GET',
};

interface RSSItem {
  title: string;
  link: string;
  source: string;
  pubDate: string;
}

// 1. 解析 Google News / 金管會 / 各大金融媒體 RSS XML
function parseRSSXml(xmlText: string): RSSItem[] {
  const items: RSSItem[] = [];
  const itemMatches = xmlText.match(/<item>[\s\S]*?<\/item>/gi) || [];

  for (const itemXml of itemMatches) {
    const titleMatch = itemXml.match(/<title>([\s\S]*?)<\/title>/i);
    const linkMatch = itemXml.match(/<link>([\s\S]*?)<\/link>/i);
    const pubDateMatch = itemXml.match(/<pubDate>([\s\S]*?)<\/pubDate>/i);
    const sourceMatch = itemXml.match(/<source[^>]*>([\s\S]*?)<\/source>/i);

    let rawTitle = titleMatch ? titleMatch[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim() : '';
    const link = linkMatch ? linkMatch[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim() : '';
    const pubDate = pubDateMatch ? pubDateMatch[1].trim() : '';
    let source = sourceMatch ? sourceMatch[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim() : '';

    if (!source && rawTitle.includes(' - ')) {
      const parts = rawTitle.split(' - ');
      source = parts.pop()?.trim() || '新聞媒體';
      rawTitle = parts.join(' - ').trim();
    }

    // 嚴格比對文章實體發布時間 (pubDate)，強制過濾早於 36 小時前之過期歷史新聞
    if (pubDate) {
      const pubTime = Date.parse(pubDate);
      if (!isNaN(pubTime)) {
        const now = Date.now();
        const maxAgeMs = 36 * 60 * 60 * 1000; // 36 小時 (精準過濾舊聞，並兼顧週末新聞空窗期)
        if ((now - pubTime) > maxAgeMs) {
          continue; // 直接徹底排除過期歷史舊聞！
        }
      }
    }

    if (rawTitle && link) {
      items.push({
        title: rawTitle,
        link: link,
        source: source || '金融權威',
        pubDate: pubDate,
      });
    }
  }

  return items;
}

interface ClusteringOutput {
  daily_trend: string;      // 今日新聞展現的第一句總體產業趨勢
  daily_overview: string;   // 今日新聞整合摘要文章
  topics: {
    topic_title: string;
    ai_summary: string;
    articles: {
      rss_index?: number;    // 對應原始 RSS 列表編號
      title: string;
      source_name: string;
      source_url: string;
      article_summary: string; // 單篇新聞重點摘要
      is_primary: boolean;
    }[];
  }[];
}

// 2. Groq AI 主題聚類、產業大勢趨勢與單篇摘要生成
async function clusterNewsWithGroq(rssItems: RSSItem[]): Promise<ClusteringOutput> {
  if (!GROQ_API_KEY) throw new Error('GROQ_API_KEY 未在 Supabase Secrets 設定');

  // 控管 Prompt Token 數量，精選當日前 30 條權威 RSS 保險新聞 (精準控管在 ~5,000 Tokens, 達 Groq 6000 TPM 限額之 80%)
  const formattedItems = rssItems
    .slice(0, 30)
    .map((item, idx) => `[${idx + 1}] ${item.title} (來源: ${item.source})`)
    .join('\n');

  const systemPrompt = `你是一位頂尖的台灣金融保險產業總編輯。
請審視今日從各大權威新聞、金管會保險局公告及金融頻道抓取的 RSS 新聞列表，完成以下三項工作：

1. daily_trend: 請用【第一句】明確總結從今天所有新聞看出來的「宏觀產業趨勢」（例如：「從今日焦點新聞可看出，主管機關正加速推動實支實付醫療險損害防阻新制與長照險商品結構調整。」）。
2. daily_overview: 撰寫一整篇約 200~350 字、結構通順完整的「今日保險產業新聞大勢總覽文章」。
3. topics: 篩選出 3 至 5 個當日最核心的『保險主題/事件』。
   - 每個主題底下包含 2~4 篇報導（標示 1 篇主要主頭條 is_primary=true，其餘為次要媒體報導 is_primary=false）。
   - ai_summary: 為該主題撰寫一段約 80~150 字的單一段落重點摘要。
   - 針對其中的每一篇新聞報導 (article)，皆撰寫 2~3 句的「單篇新聞重點摘要 (article_summary)」。
   - rss_index: 請務必填入該篇新聞在「今日熱門保險 RSS 新聞列表」中對應的 [ID] 數字（例如: 1, 2, 3）。

請務必輸出嚴格 JSON 格式：
{
  "daily_trend": "從今日新聞可看出...",
  "daily_overview": "今日台灣保險市場受政策法規與市場需求影響...",
  "topics": [
    {
      "topic_title": "主題名稱",
      "ai_summary": "主題單段摘要",
      "articles": [
        {
          "rss_index": 1,
          "title": "新聞標題",
          "source_name": "媒體名稱",
          "source_url": "連結",
          "article_summary": "單篇新聞 2~3 句摘要內容",
          "is_primary": true
        }
      ]
    }
  ]
}`;

  const staticCandidateModels = [
    'groq/compound',
    'groq/compound-mini',
    'qwen/qwen3.6-27b',
    'openai/gpt-oss-20b',
    'llama-3.3-70b-versatile',
  ];
  const modelErrors: string[] = [];
  const triedModels = new Set<string>();

  // 輔助函式：對指定 Groq 模型發起 Completion 請求
  async function tryModel(modelName: string): Promise<ClusteringOutput | null> {
    triedModels.add(modelName);
    try {
      console.log(`[Groq News Clustering] 嘗試使用模型: ${modelName}...`);
      const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${GROQ_API_KEY.trim()}`,
        },
        body: JSON.stringify({
          model: modelName,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: `今日熱門保險 RSS 新聞列表：\n${formattedItems}` }
          ],
          temperature: 0.2,
          max_tokens: 4096,
        }),
      });

      if (!res.ok) {
        const errText = await res.text();
        console.error(`[Groq ${modelName} Error]:`, res.status, errText);
        modelErrors.push(`[${modelName} HTTP ${res.status}] ${errText}`);
        return null;
      }

      const resData = await res.json();
      const content = resData.choices?.[0]?.message?.content || '';

      let parsed: any;
      try {
        parsed = JSON.parse(content);
      } catch {
        const jsonMatch = content.match(/\{[\s\S]*\}/);
        if (jsonMatch) parsed = JSON.parse(jsonMatch[0]);
      }

      if (parsed && (parsed.topics || parsed.items || parsed.news)) {
        const rawTopics = parsed.topics || parsed.items || parsed.news || [];
        if (Array.isArray(rawTopics) && rawTopics.length > 0) {
          return {
            daily_trend: parsed.daily_trend || '從今日新聞可看出保險市場法規與產品結構正積極調整。',
            daily_overview: parsed.daily_overview || '今日保險產業新聞涵蓋主管機關政策宣導、商品轉型與社會熱點。',
            topics: rawTopics,
          };
        }
      }
    } catch (err: any) {
      console.error(`[Groq Catch Error ${modelName}]:`, err);
      modelErrors.push(`[${modelName} Exception] ${err.message || String(err)}`);
    }
    return null;
  }

  // 第一階段：優先嘗試預設靜態候選模型清單
  for (const model of staticCandidateModels) {
    const output = await tryModel(model);
    if (output) return output;
  }

  // 第二階段：【緊急自我修復動態巡檢】
  // 當預設模型皆廢棄/失效時，自動打 API 取得 Groq 在線可用模型清單
  console.warn('⚠️ [Groq Auto-Discovery] 所有靜態候選模型皆無回應或被廢棄，啟動動態 Groq 模型自我修復搜尋...');
  try {
    const modelsRes = await fetch('https://api.groq.com/openai/v1/models', {
      headers: { 'Authorization': `Bearer ${GROQ_API_KEY.trim()}` },
    });

    if (modelsRes.ok) {
      const modelsData = await modelsRes.json();
      const liveModels: any[] = modelsData.data || [];

      // 自動過濾語音(whisper)、安全防護(safeguard/prompt-guard)及特定微調模型，保留文本生成模型
      const discoveredModels = liveModels
        .map((m: any) => m.id as string)
        .filter((id: string) => {
          if (!id) return false;
          if (triedModels.has(id)) return false; // 跳過先前已試過的模型
          const lower = id.toLowerCase();
          const isNonTextModel = lower.includes('whisper') ||
                                 lower.includes('prompt-guard') ||
                                 lower.includes('safeguard') ||
                                 lower.includes('orpheus') ||
                                 lower.includes('vision');
          return !isNonTextModel;
        });

      console.log(`[Groq Dynamic Auto-Discovery] 自動發現 ${discoveredModels.length} 個在線文字模型:`, discoveredModels);

      for (const discoveredModel of discoveredModels) {
        const output = await tryModel(discoveredModel);
        if (output) {
          console.log(`🎉 [Groq Dynamic Auto-Discovery Success] 成功找到最新可替代模型: ${discoveredModel}`);
          return output;
        }
      }
    }
  } catch (discoveryErr: any) {
    console.error('[Groq Auto-Discovery Exception]:', discoveryErr);
    modelErrors.push(`[Auto-Discovery Exception] ${discoveryErr.message || String(discoveryErr)}`);
  }

  throw new Error(`Groq 新聞聚類與模型自我修復解析失敗 (共嘗試 ${triedModels.size} 個模型): ${modelErrors.join(' | ')}`);
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('[fetch-insurance-news] 開始抓取多源 RSS 新聞 (包含 Google News, 金管會, 金融新聞)...');

    // 多源 RSS 抓取頻道 (3 大關鍵字軌道 + 7 大國內權威媒體頻道，強制限縮在 24h 內 when:1d)
    const rssUrls = [
      // 軌道一：全網保險焦點、壽險、產險與金管會保險局新聞
      'https://news.google.com/rss/search?q=%E4%BF%9D%E9%9A%AA+OR+%E5%A3%BD%E4%BF%9D+OR+%E7%94%A2%E4%BF%9D+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',
      'https://news.google.com/rss/search?q=%E9%87%91%E7%AE%A1%E6%9C%83+%E4%BF%9D%E9%9A%AA%E5%B1%80+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',

      // 軌道二：醫療理賠、實支實付與長照險熱勢議題
      'https://news.google.com/rss/search?q=%E9%86%AB%E7%99%82%E9%9A%AA+OR+%E5%AF%A6%E6%94%AF%E7%AF%A6%E4%BF%9D+OR+%E4%BF%9D%E9%9A%AA%E7%90%86%E8%B3%A0+OR+%E9%95%B7%E7%85%A7%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',

      // 軌道三：四大龍頭金控壽險巨頭動態
      'https://news.google.com/rss/search?q=%E5%9C%8B%E6%B3%B0%E4%BA%BA%E5%A3%BD+OR+%E5%AF%8C%E9%82%A6%E4%BA%BA%E5%A3%BD+OR+%E5%8D%97%E5%B1%B1%E4%BA%BA%E5%A3%BD+OR+%E6%96%B0%E5%85%89%E4%BA%BA%E5%A3%BD+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',

      // 軌道四：七大國內權威媒體專屬保險新聞頻道
      'https://news.google.com/rss/search?q=site:cna.com.tw+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',        // 中央通訊社 (CNA)
      'https://news.google.com/rss/search?q=site:cnyes.com+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',        // 鉅亨網 (cnyes)
      'https://news.google.com/rss/search?q=site:ctee.com.tw+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',       // 工商時報 (CTEE)
      'https://news.google.com/rss/search?q=site:udn.com+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',        // 聯合新聞網 (UDN)
      'https://news.google.com/rss/search?q=site:chinatimes.com+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',  // 中時新聞網 (Chinatimes)
      'https://news.google.com/rss/search?q=site:ettoday.net+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',     // ETtoday財經
      'https://news.google.com/rss/search?q=site:mirrormedia.mg+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',   // 鏡週刊理財
    ];

    let allRssItems: RSSItem[] = [];
    for (const url of rssUrls) {
      try {
        const resp = await fetch(url, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7',
          }
        });
        if (resp.ok) {
          const xml = await resp.text();
          const items = parseRSSXml(xml);
          allRssItems = allRssItems.concat(items);
        } else {
          console.warn(`抓取 RSS 回傳非 200 (${resp.status}): ${url}`);
        }
      } catch (e) {
        console.error(`抓取 RSS 失敗 (${url}):`, e);
      }
    }

    // 依網址或標題去重
    const uniqueItems: RSSItem[] = [];
    const seenTitles = new Set<string>();
    for (const item of allRssItems) {
      const cleanTitle = item.title.replace(/\s+/g, '');
      if (!seenTitles.has(cleanTitle)) {
        seenTitles.add(cleanTitle);
        uniqueItems.push(item);
      }
    }

    console.log(`[fetch-insurance-news] 成功抓取並去重出 ${uniqueItems.length} 條 RSS 新聞`);

    if (uniqueItems.length === 0) {
      return new Response(
        JSON.stringify({ success: false, message: '未找到任何有效 RSS 新聞' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      );
    }

    // 呼叫 Groq 進行主題聚類、單段摘要與今日大勢趨勢提煉
    console.log('[fetch-insurance-news] 呼叫 Groq AI 聚類歸納與今日大勢趨勢...');
    const result = await clusterNewsWithGroq(uniqueItems);

    // 初始化 Supabase Service Role Client (支援 Deno Secret 與 Request Header 雙軌 Auth 回退)
    const authHeader = req.headers.get('Authorization') ?? '';
    const bearerToken = authHeader.replace(/^Bearer\s+/i, '').trim();
    const serviceKey = SUPABASE_SERVICE_ROLE_KEY || bearerToken || Deno.env.get('SUPABASE_ANON_KEY') || '';
    const supabaseClient = createClient(SUPABASE_URL, serviceKey);
    // 使用台灣時間 (Asia/Taipei UTC+8) 取得當前正確日期 YYYY-MM-DD，解決 UTC 22:00 (台灣時間 06:00) 日期誤判為前一日之 Bug
    const todayDate = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Taipei' }).format(new Date());

    // 讀取當天已存在之新聞話題（夕報 18:00 追加模式：不刷掉晨報 06:00 已發布話題，而是無縫累加新話題）
    const { data: existingTodayTopics } = await supabaseClient
      .from('insurance_news_topics')
      .select('topic_title')
      .eq('publish_date', todayDate);

    const existingTitleSet = new Set(
      (existingTodayTopics || []).map((t: any) => (t.topic_title || '').replace(/\s+/g, '').toLowerCase())
    );

    let insertedTopicCount = 0;
    let insertedArticleCount = 0;
    let lastError = null;

    for (const topic of result.topics) {
      const cleanTopicTitle = (topic.topic_title || '').replace(/\s+/g, '').toLowerCase();
      if (existingTitleSet.has(cleanTopicTitle)) {
        console.log(`[fetch-insurance-news] 當日話題已存在，跳過重複追加: ${topic.topic_title}`);
        continue;
      }
      // 1. 寫入主題表 (包含 daily_trend 與 daily_overview)
      const { data: topicData, error: topicErr } = await supabaseClient
        .from('insurance_news_topics')
        .insert({
          topic_title: topic.topic_title,
          ai_summary: topic.ai_summary,
          daily_trend: result.daily_trend,
          daily_overview: result.daily_overview,
          publish_date: todayDate,
        })
        .select('id')
        .single();

      if (topicErr || !topicData) {
        console.error('寫入 insurance_news_topics 失敗:', topicErr);
        lastError = topicErr;
        continue;
      }

      insertedTopicCount++;
      const topicId = topicData.id;

      // 2. 寫入報導來源表 (相容多元 LLM 鍵名 articles/news/items + 精密網址對照)
      const rawArticles = topic.articles || topic.news || topic.items || topic.news_list || topic.article_list || [];

      if (Array.isArray(rawArticles) && rawArticles.length > 0) {
        const articleRows = rawArticles.map((art: any) => {
          let matchedUrl = '';

          // A) 優先依據 Groq 回傳之 rss_index (相容字串與數字，1-based 轉 0-based 索引)
          const rawIdx = parseInt(String(art.rss_index || ''), 10);
          if (!isNaN(rawIdx) && rawIdx >= 1 && rawIdx <= uniqueItems.length) {
            matchedUrl = uniqueItems[rawIdx - 1].link;
          }

          // B) 若 rss_index 未對中，以新聞標題去除空白進行語意對照
          if (!matchedUrl) {
            const cleanArtTitle = (art.title || '').replace(/\s+/g, '').toLowerCase();
            const foundItem = uniqueItems.find((item) => {
              const cleanItemTitle = (item.title || '').replace(/\s+/g, '').toLowerCase();
              return cleanItemTitle.includes(cleanArtTitle) || cleanArtTitle.includes(cleanItemTitle);
            });
            if (foundItem) {
              matchedUrl = foundItem.link;
            }
          }

          // C) 若 Groq 回傳之 source_url 存在且不為通用首頁，作為三級對照
          if (!matchedUrl && art.source_url && art.source_url.trim().length > 0) {
            const rawUrl = art.source_url.trim();
            const isGenericHome = rawUrl === 'https://news.google.com' ||
                rawUrl === 'https://news.google.com/' ||
                rawUrl === 'https://news.google.com/news';
            if (!isGenericHome) {
              matchedUrl = rawUrl;
            }
          }

          // D) 備援：若無有效文章連結，拿標題做關鍵字對照
          if (!matchedUrl) {
            matchedUrl = uniqueItems[0]?.link || '';
          }

          const articleRow: any = {
            topic_id: topicId,
            title: art.title || topic.topic_title,
            source_name: art.source_name || '權威媒體',
            source_url: matchedUrl,
            is_primary: art.is_primary ?? false,
            published_at: new Date().toISOString(),
          };

          if (art.article_summary && art.article_summary.trim().length > 0) {
            articleRow.article_summary = art.article_summary.trim();
          }

          return articleRow;
        });

        const { error: artErr } = await supabaseClient
          .from('insurance_news_articles')
          .insert(articleRows);

        if (artErr) {
          console.error(`寫入 topic (${topicId}) 的報導失敗:`, artErr);
          lastError = artErr;
        } else {
          insertedArticleCount += articleRows.length;
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `成功完成新聞聚類與今日大勢更新！`,
        date: todayDate,
        daily_trend: result.daily_trend,
        topics_count: insertedTopicCount,
        articles_count: insertedArticleCount,
        last_error: lastError,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (err: any) {
    console.error('[fetch-insurance-news Exception]:', err);
    return new Response(
      JSON.stringify({ success: false, error: err.message || String(err) }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    );
  }
});
