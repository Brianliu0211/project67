import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') ?? '';
const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

async function transcribeWithGroq(audioBase64: string): Promise<{ text: string | null; err?: string }> {
  if (!GROQ_API_KEY) return { text: null, err: 'GROQ_API_KEY 未在 Supabase Secrets 中設定' };
  
  try {
    // 1. 將 base64 轉為 Uint8Array
    const binaryStr = atob(audioBase64);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }

    // 2. 建立標準 File 物件 (Deno 支援)
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
      console.error('Groq error:', res.status, resText);
      return { text: null, err: `[Groq ${res.status}]: ${resText}` };
    }
  } catch (e) {
    console.error('Groq catch:', e);
    return { text: null, err: `Groq catch: ${e}` };
  }
}

async function transcribeWithGemini(audioBase64: string, mimeType: string): Promise<{ text: string | null; err?: string }> {
  if (!GEMINI_API_KEY) return { text: null, err: 'GEMINI_API_KEY 未設定' };
  
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY.trim()}`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            role: 'user',
            parts: [
              {
                inline_data: {
                  mime_type: mimeType,
                  data: audioBase64,
                },
              },
              {
                text: `你是一位保險業務員的智慧語音助理。請將以下語音內容轉錄為繁體中文文字。
若有多項重要資訊，請以「•」開頭條列呈現。保留原始說話的完整資訊，不需要額外解釋。`,
              },
            ],
          },
        ],
        generationConfig: { temperature: 0.1 },
      }),
    });

    const resText = await res.text();
    if (res.ok) {
      const data = JSON.parse(resText);
      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? null;
      return { text };
    } else {
      return { text: null, err: `[Gemini ${res.status}]: ${resText}` };
    }
  } catch (e) {
    return { text: null, err: `Gemini catch: ${e}` };
  }
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { audioBase64, mimeType } = await req.json();

    if (!audioBase64) {
      return new Response(
        JSON.stringify({ error: '缺少音訊資料 (audioBase64)' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const resolvedMimeType = mimeType || 'audio/webm';

    // 優先 1：Groq Whisper
    const groqResult = await transcribeWithGroq(audioBase64);
    if (groqResult.text) {
      return new Response(
        JSON.stringify({ transcript: groqResult.text, engine: 'Groq-Whisper' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 優先 2：Gemini 2.0 Flash
    const geminiResult = await transcribeWithGemini(audioBase64, resolvedMimeType);
    if (geminiResult.text) {
      return new Response(
        JSON.stringify({ transcript: geminiResult.text, engine: 'Gemini-2.0-Flash' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 回傳包含 Groq 與 Gemini 兩者的診斷原因
    return new Response(
      JSON.stringify({
        error: '語音轉錄失敗，請檢查 API Key 或詳細紀錄',
        groqError: groqResult.err,
        geminiError: geminiResult.err,
      }),
      { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Edge Function internal error:', error);
    return new Response(
      JSON.stringify({ error: `伺服器處理失敗: ${error}` }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
