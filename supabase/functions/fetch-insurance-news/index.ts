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
    category: string;
    ai_summary: string;
    articles: {
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

  const formattedItems = rssItems.slice(0, 40).map((item, idx) => `[${idx + 1}] 標題: ${item.title} | 來源: ${item.source} | 連結: ${item.link}`).join('\n');

  const systemPrompt = `你是一位頂尖的台灣金融保險產業總編輯。
請審視今日從各大權威新聞、金管會保險局公告及金融頻道抓取的 RSS 新聞列表，完成以下三項工作：

1. daily_trend: 請用【第一句】明確總結從今天所有新聞看出來的「宏觀產業趨勢」（例如：「從今日焦點新聞可看出，主管機關正加速推動實支實付醫療險損害防阻新制與長照險商品結構調整。」）。
2. daily_overview: 撰寫一整篇約 200~350 字、結構通順完整的「今日保險產業新聞大勢總覽文章」。
3. topics: 篩選出 3 至 5 個當日最核心的『保險主題/事件』。
   - 每個主題底下包含 2~4 篇報導（標示 1 篇主要主頭條 is_primary=true，其餘為次要媒體報導 is_primary=false）。
   - ai_summary: 為該主題撰寫一段約 80~150 字的單一段落重點摘要。
   - 針對其中的每一篇新聞報導 (article)，皆撰寫 2~3 句的「單篇新聞重點摘要 (article_summary)」。
   - category: 請從「法規政策」、「產品趨勢」、「理賠法規」、「社會熱點」、「保險焦點」中擇一。

請務必輸出嚴格 JSON 格式：
{
  "daily_trend": "從今日新聞可看出...",
  "daily_overview": "今日台灣保險市場受政策法規與市場需求影響...",
  "topics": [
    {
      "topic_title": "主題名稱",
      "category": "法規政策",
      "ai_summary": "主題單段摘要",
      "articles": [
        {
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

  const models = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'];
  for (const model of models) {
    try {
      console.log(`[Groq News Clustering] 嘗試使用模型: ${model}...`);
      const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${GROQ_API_KEY.trim()}`,
        },
        body: JSON.stringify({
          model: model,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: `今日熱門保險 RSS 新聞列表：\n${formattedItems}` }
          ],
          temperature: 0.3,
        }),
      });

      if (!res.ok) {
        console.error(`[Groq ${model} Error]:`, res.status, await res.text());
        continue;
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

      if (parsed && parsed.topics && parsed.topics.length > 0) {
        return {
          daily_trend: parsed.daily_trend || '從今日新聞可看出保險市場法規與產品結構正積極調整。',
          daily_overview: parsed.daily_overview || '今日保險產業新聞涵蓋主管機關政策宣導、商品轉型與社會熱點。',
          topics: parsed.topics,
        };
      }
    } catch (err) {
      console.error(`[Groq Catch Error ${model}]:`, err);
    }
  }

  throw new Error('Groq 新聞聚類解析失敗');
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('[fetch-insurance-news] 開始抓取多源 RSS 新聞 (包含 Google News, 金管會, 金融新聞)...');

    // 多源 RSS 抓取頻道 (雙軌聚合：Google News 引擎 + 權威媒體原生 RSS)
    const rssUrls = [
      // 軌道一：Google News 深度主題聚合 RSS
      'https://news.google.com/rss/search?q=%E4%BF%9D%E9%9A%AA+OR+%E5%A3%BD%E4%BF%9D+OR+%E7%94%A2%E4%BF%9D&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',
      'https://news.google.com/rss/search?q=%E9%87%91%E7%AE%A1%E6%9C%83+%E4%BF%9D%E9%9A%AA%E5%B1%80&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',
      'https://news.google.com/rss/search?q=%E9%87%91%E8%9E%8D+%E4%BF%9D%E9%9A%AA%E5%85%AC%E6%9C%83&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',

      // 軌道二：國內權威財經與新聞媒體原生 RSS
      'https://www.cna.com.tw/cna2010/market/rss.xml',       // 中央通訊社 (CNA) 財經新聞 RSS
      'https://news.cnyes.com/rss/pref/news/cat/tw_macro',    // 鉅亨網 (Anue) 台灣總體經濟與金融 RSS
      'https://ctee.com.tw/feed',                            // 工商時報 (CTEE) 產經理財 RSS
      'https://udn.com/rss/news/2/6645',                     // 聯合新聞網 (UDN) 保險與理財 RSS
    ];

    let allRssItems: RSSItem[] = [];
    for (const url of rssUrls) {
      try {
        const resp = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
        if (resp.ok) {
          const xml = await resp.text();
          const items = parseRSSXml(xml);
          allRssItems = allRssItems.concat(items);
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

    // 初始化 Supabase Service Role Client
    const supabaseClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const todayDate = new Date().toISOString().split('T')[0];

    let insertedTopicCount = 0;
    let insertedArticleCount = 0;

    for (const topic of result.topics) {
      // 1. 寫入主題表 (包含 daily_trend 與 daily_overview)
      const { data: topicData, error: topicErr } = await supabaseClient
        .from('insurance_news_topics')
        .insert({
          topic_title: topic.topic_title,
          category: topic.category || '保險焦點',
          ai_summary: topic.ai_summary,
          daily_trend: result.daily_trend,
          daily_overview: result.daily_overview,
          publish_date: todayDate,
        })
        .select('id')
        .single();

      if (topicErr || !topicData) {
        console.error('寫入 insurance_news_topics 失敗:', topicErr);
        continue;
      }

      insertedTopicCount++;
      const topicId = topicData.id;

      // 2. 寫入報導來源表 (包含 article_summary)
      if (topic.articles && topic.articles.length > 0) {
        const articleRows = topic.articles.map((art) => ({
          topic_id: topicId,
          title: art.title,
          source_name: art.source_name,
          source_url: art.source_url,
          article_summary: art.article_summary || art.title,
          is_primary: art.is_primary ?? false,
          published_at: new Date().toISOString(),
        }));

        const { error: artErr } = await supabaseClient
          .from('insurance_news_articles')
          .insert(articleRows);

        if (artErr) {
          console.error(`寫入 topic (${topicId}) 的報導失敗:`, artErr);
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
