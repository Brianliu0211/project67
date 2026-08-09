-- =================================================================
-- Migration: Create Insurance News Topics and Articles (Phase 7 v2)
-- Date: 2026-08-06
-- Description: Google News 主題聚類風保險新聞資料表 (含當日產業大勢趨勢與單篇摘要)
-- =================================================================

-- 1. 建立保險焦點新聞主題表 (insurance_news_topics)
CREATE TABLE IF NOT EXISTS public.insurance_news_topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_title TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT '保險焦點',
    main_image_url TEXT,
    ai_summary TEXT NOT NULL,
    daily_trend TEXT,        -- 當日全網總體產業趨勢的一句話
    daily_overview TEXT,     -- 當日新聞整合摘要文章
    publish_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. 建立媒體報導來源關聯表 (insurance_news_articles)
CREATE TABLE IF NOT EXISTS public.insurance_news_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_id UUID NOT NULL REFERENCES public.insurance_news_topics(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    source_name TEXT NOT NULL,
    source_url TEXT NOT NULL,
    article_summary TEXT,    -- 單篇新聞 AI 重點摘要
    published_at TIMESTAMPTZ,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. 建立索引提升查詢效率
CREATE INDEX IF NOT EXISTS idx_insurance_news_topics_date ON public.insurance_news_topics(publish_date DESC);
CREATE INDEX IF NOT EXISTS idx_insurance_news_articles_topic_id ON public.insurance_news_articles(topic_id);

-- 4. 啟用 Row Level Security (RLS)
ALTER TABLE public.insurance_news_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insurance_news_articles ENABLE ROW LEVEL SECURITY;

-- 5. 建立 RLS 讀取與寫入權限 (允許所有驗證與匿名使用者存取)
DROP POLICY IF EXISTS "Allow public read access for insurance_news_topics" ON public.insurance_news_topics;
DROP POLICY IF EXISTS "Allow public all access for insurance_news_topics" ON public.insurance_news_topics;
CREATE POLICY "Allow public all access for insurance_news_topics"
    ON public.insurance_news_topics FOR ALL
    TO public
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read access for insurance_news_articles" ON public.insurance_news_articles;
DROP POLICY IF EXISTS "Allow public all access for insurance_news_articles" ON public.insurance_news_articles;
CREATE POLICY "Allow public all access for insurance_news_articles"
    ON public.insurance_news_articles FOR ALL
    TO public
    USING (true)
    WITH CHECK (true);
