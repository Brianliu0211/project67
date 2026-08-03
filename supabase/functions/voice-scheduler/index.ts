import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// 1. Groq Whisper (STT) 語音轉錄
async function transcribeWithGroq(audioBase64: string): Promise<{ text: string | null; err?: string }> {
  if (!GROQ_API_KEY) return { text: null, err: 'GROQ_API_KEY 未在 Supabase Secrets 中設定' };
  
  try {
    const binaryStr = atob(audioBase64);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }

    const file = new File([bytes], 'audio.webm', { type: 'audio/webm' });
    const formData = new FormData();
    formData.append('file', file);
    formData.append('model', 'whisper-large-v3-turbo');
    formData.append('language', 'zh');
    formData.append('response_format', 'json');

    const res = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${GROQ_API_KEY.trim()}`,
      },
      body: formData,
    });

    const resText = await res.text();
    if (res.ok) {
      const data = JSON.parse(resText);
      return { text: data.text ?? null };
    } else {
      console.error('Groq STT error:', res.status, resText);
      return { text: null, err: `[Groq STT ${res.status}]: ${resText}` };
    }
  } catch (e) {
    console.error('Groq STT catch:', e);
    return { text: null, err: `Groq STT catch: ${e}` };
  }
}

interface ScheduleParseResult {
  title: string;
  start_at: string;
  end_at: string;
  customer_name: string | null;
  location: string | null;
  is_time_defaulted: boolean;
  is_title_defaulted: boolean;
}

// 2. Groq 語意解析 (自適應模型輪替)
async function parseScheduleWithGroq(transcript: string, localTime: string): Promise<ScheduleParseResult> {
  if (!GROQ_API_KEY) throw new Error('GROQ_API_KEY 未設定，無法使用 Groq 解析');

  const models = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant', 'llama3-70b-8192'];
  let lastError = null;

  for (const model of models) {
    try {
      console.log(`[Groq NLU] 嘗試使用模型: ${model} ...`);
      const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${GROQ_API_KEY.trim()}`,
        },
        body: JSON.stringify({
          model: model,
          messages: [
            {
              role: 'system',
              content: `你是一位智慧行事曆助理。請根據使用者所在基準時間 (localTime)，推算行程的絕對開始時間 (start_at) 與結束時間 (end_at)。
並從語音文字中提取出：行程標題 (title)、提及的客戶姓名或稱謂 (customer_name) 與地點 (location)。

請嚴格遵循以下規則：
1. 輸出必須是嚴格 JSON 格式。不要有 markdown 標記，必須可以直接被 JSON.parse() 解析。
2. JSON 包含以下欄位：
   - title: 行程標題 (如 "與張總開會")，請精簡有意義。若語意中完全沒提及做什麼，請設為預設標題 (如 "商務行程")。
   - start_at: 行程開始時間，使用 ISO 8601 格式且必須包含與 localTime 相同的時區偏移量 (例如: "2026-08-04T15:00:00+08:00")。若沒提及具體時間或日期，請預設為 localTime 日期的當天 18:00 (例如: "2026-08-03T18:00:00+08:00")。
   - end_at: 行程結束時間，使用 ISO 8601 格式且必須包含與 localTime 相同的時區偏移量。若未提及持續時間，預設為 start_at 往後推算 1 小時。
   - customer_name: 提到的聯絡客戶姓名或稱謂 (如 "張總", "林經理")，若未提及請設為 null。
   - location: 提到的地點，若未提及請設為 null。
   - is_time_defaulted: 布林值。若語音中未提及具體日期或時間，因而使用了系統預設時間，請設為 true，否則為 false。
   - is_title_defaulted: 布林值。若語音中未提及行程主題，因而使用了預設標題，請設為 true，否則為 false。
3. 若提及「明天」，代表基準時間的隔天。若提及「後天」，代表基準時間的後兩天。`
            },
            {
              role: 'user',
              content: `基準時間 (localTime): ${localTime}
行程語音內容: "${transcript}"`
            }
          ],
          temperature: 0.1,
          response_format: { type: 'json_object' }
        })
      });

      const resText = await res.text();
      if (res.ok) {
        const data = JSON.parse(resText);
        const jsonStr = data?.choices?.[0]?.message?.content;
        if (!jsonStr) {
          throw new Error('Groq 語意解析未回傳 choices 內容');
        }
        return JSON.parse(jsonStr) as ScheduleParseResult;
      } else {
        throw new Error(`[Groq NLU ${model} ${res.status}]: ${resText}`);
      }
    } catch (e) {
      console.warn(`[Groq NLU] 模型 ${model} 呼叫失敗，將嘗試下一個。錯誤:`, e.message || e);
      lastError = e;
    }
  }

  throw lastError || new Error('所有 Groq 模型均呼叫失敗');
}

// 3. Edge Function 進入點
serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { audioBase64, mimeType, localTime } = await req.json();

    if (!audioBase64) {
      return new Response(
        JSON.stringify({ error: '缺少音訊資料 (audioBase64)' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!localTime) {
      return new Response(
        JSON.stringify({ error: '缺少基準時間 (localTime)' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 步驟 1：語音轉錄為純文字 (僅使用 Groq Whisper)
    let transcriptText = '';
    const groqResult = await transcribeWithGroq(audioBase64);
    
    if (groqResult.text) {
      transcriptText = groqResult.text;
    } else {
      console.error('Groq STT 失敗:', groqResult.err);
      return new Response(
        JSON.stringify({
          error: '語音辨識失敗，請確認麥克風運作正常且音訊清晰。',
          details: { groq: groqResult.err }
        }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`[STT] 轉錄內容 (Groq-Whisper): "${transcriptText}"`);

    // 步驟 2：語意提取 (使用 Groq 自適應)
    let parsedResult: ScheduleParseResult;
    try {
      console.log('嘗試使用 Groq 自適應模型進行語意解析...');
      parsedResult = await parseScheduleWithGroq(transcriptText, localTime);
      console.log('[NLU] Groq-Adaptive-Llama 解析成功:', parsedResult);
    } catch (groqNluError) {
      console.error('Groq 語意分析失敗:', groqNluError);
      return new Response(
        JSON.stringify({
          error: '行程智慧解析失敗，請確認 Groq API 金鑰配置無誤。',
          details: { groq: groqNluError instanceof Error ? groqNluError.message : groqNluError }
        }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 步驟 3：資料庫比對與寫入 (JWT 使用者認證)
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: '缺少 Authorization Header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    });

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token);
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: `使用者驗證失敗: ${userError?.message || '未登入'}` }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 匹配客戶 id (如果有提及客戶名稱)
    let matchedCustomerId: string | null = null;
    let matchedCustomerName: string | null = null;

    if (parsedResult.customer_name) {
      let cleanName = parsedResult.customer_name;
      const titleSuffixes = ['經理', '總', '先生', '小姐', '姐', '哥', '董', '副總', '協理', '專員', '主任', '阿姨'];
      for (const suffix of titleSuffixes) {
        if (cleanName.endsWith(suffix) && cleanName.length > suffix.length) {
          cleanName = cleanName.substring(0, cleanName.length - suffix.length);
          break;
        }
      }

      const { data: customers, error: customerQueryError } = await supabaseClient
        .from('customers')
        .select('id, name')
        .is('deleted_at', null)
        .or(`name.ilike.%${cleanName}%,nickname.ilike.%${cleanName}%`)
        .limit(1);

      if (customerQueryError) {
        console.error('查詢客戶時發生錯誤:', customerQueryError);
      }

      if (customers && customers.length > 0) {
        matchedCustomerId = customers[0].id;
        matchedCustomerName = customers[0].name;
        console.log(`[Customer Match] 成功匹配客戶: ${matchedCustomerName} (ID: ${matchedCustomerId})`);
      } else {
        console.log(`[Customer Match] 未能匹配到包含 "${cleanName}" 的客戶`);
      }
    }

    // 判定紅黃綠燈狀態與警示訊息
    let status = 'green';
    const warningMessages: string[] = [];

    if (parsedResult.is_time_defaulted) {
      status = 'yellow';
      // 格式化顯示時間，例如 "18:00"
      let formattedTime = '18:00';
      try {
        const dateObj = new Date(parsedResult.start_at);
        const hours = dateObj.getHours().toString().padStart(2, '0');
        const minutes = dateObj.getMinutes().toString().padStart(2, '0');
        formattedTime = `${hours}:${minutes}`;
      } catch (e) {
        // ignore
      }
      warningMessages.push(`未偵測到行程時間，已自動預設為今日 ${formattedTime}`);
    }

    if (parsedResult.is_title_defaulted) {
      status = 'yellow';
      warningMessages.push(`未偵測到具體行程標題，已預設為「${parsedResult.title}」`);
    }

    if (parsedResult.customer_name && !matchedCustomerId) {
      status = 'yellow';
      warningMessages.push(`找不到聯絡人「${parsedResult.customer_name}」，已先建立為個人行程`);
    }

    const eventType = matchedCustomerId ? 'meeting' : 'personal';

    // 插入 schedule_events 資料表
    const { data: insertedEvent, error: insertError } = await supabaseClient
      .from('schedule_events')
      .insert({
        profile_id: user.id,
        customer_id: matchedCustomerId,
        title: parsedResult.title,
        start_at: parsedResult.start_at,
        end_at: parsedResult.end_at,
        location: parsedResult.location,
        event_type: eventType,
        is_completed: false,
      })
      .select('*, customers(name, nickname)')
      .single();

    if (insertError) {
      console.error('行程寫入資料庫失敗:', insertError);
      return new Response(
        JSON.stringify({ error: `行程建立失敗: ${insertError.message}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('[Database Insert] 成功建立行程:', insertedEvent);

    return new Response(
      JSON.stringify({
        success: true,
        status: status,
        warning_messages: warningMessages,
        transcript: transcriptText,
        nluEngine: 'Groq-Adaptive-Llama',
        event: insertedEvent,
        matchedCustomer: matchedCustomerName ? { id: matchedCustomerId, name: matchedCustomerName } : null
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Edge Function 內部錯誤:', error);
    return new Response(
      JSON.stringify({ error: `伺服器內部錯誤: ${error instanceof Error ? error.message : error}` }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
