-- Migration: 20260817_news_rss_sources.sql
-- Table-driven Dynamic RSS Sources for Insurance & Financial News

CREATE TABLE IF NOT EXISTS public.news_rss_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_name TEXT NOT NULL,
    rss_url TEXT NOT NULL UNIQUE,
    category TEXT DEFAULT '保險財經',
    is_active BOOLEAN DEFAULT true,
    health_status TEXT DEFAULT '200 OK',
    last_fetched_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.news_rss_sources ENABLE ROW LEVEL SECURITY;

-- Policies for public / authenticated read & write
CREATE POLICY "Allow public read on news_rss_sources"
    ON public.news_rss_sources FOR SELECT
    USING (true);

CREATE POLICY "Allow anon and auth insert on news_rss_sources"
    ON public.news_rss_sources FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Allow anon and auth update on news_rss_sources"
    ON public.news_rss_sources FOR UPDATE
    USING (true);

CREATE POLICY "Allow anon and auth delete on news_rss_sources"
    ON public.news_rss_sources FOR DELETE
    USING (true);

-- Seed initial 7 authoritative news sources if not exist
INSERT INTO public.news_rss_sources (source_name, rss_url, category, is_active, health_status)
VALUES 
    ('中央社 - 產經金融', 'https://feeds.feedburner.com/cnaFirstNews', '權威通訊社', true, '200 OK'),
    ('鉅亨網 - 保險理財', 'https://news.cnyes.com/rss/category/insurance', '財經專業', true, '200 OK'),
    ('工商時報 - 金融保險', 'https://ctee.com.tw/feed', '產經大報', true, '200 OK'),
    ('經濟日報 - 金融要聞', 'https://money.udn.com/rssfeed/news/1001/5591', '財經權威', true, '200 OK'),
    ('數位時代 - 科技金融', 'https://www.bnext.com.tw/rss', '創新科技', true, '200 OK'),
    ('保險事業發展中心 (TII)', 'https://www.tii.org.tw/open-data/rss/news.xml', '官方機構', true, '200 OK'),
    ('金管會保險局 - 最新公告', 'https://www.ib.gov.tw/ch/rss/bulletin.xml', '監理主管', true, '200 OK')
ON CONFLICT (rss_url) DO UPDATE 
SET source_name = EXCLUDED.source_name, is_active = EXCLUDED.is_active;
