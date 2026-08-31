-- ==========================================
-- Supabase / PostgreSQL Database Schema Design
-- Project: Insurance Client CRM Helper (insurance_helper)
-- Description: Core tables with RLS (Row Level Security) and auto-updating timestamps.
-- ==========================================

-- Enable UUID generation extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -------------------------------------------------------------
-- 1. Profiles Table (Sales Reps / App Users)
-- -------------------------------------------------------------
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    phone TEXT,
    company TEXT,
    job_title TEXT,
    website TEXT,
    address TEXT,
    bio TEXT,
    role TEXT NOT NULL DEFAULT 'agent' CHECK (role IN ('admin', 'dev', 'agent')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pending', 'suspended')),
    team_id UUID DEFAULT 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::UUID,
    team_name TEXT DEFAULT '國泰台北第一通訊處',
    is_google_connected BOOLEAN NOT NULL DEFAULT FALSE,
    connected_providers TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

COMMENT ON TABLE public.profiles IS 'Stores basic salesperson profile metadata, linked to Supabase Auth users.';
COMMENT ON COLUMN public.profiles.role IS 'User role for Role-Based Access Control: admin, dev, agent (default)';
COMMENT ON COLUMN public.profiles.status IS 'Account status: active, pending, suspended';
COMMENT ON COLUMN public.profiles.team_id IS 'Team / Organization UUID for multi-tenant isolation';
COMMENT ON COLUMN public.profiles.is_google_connected IS 'Indicates whether the user has authorized Google account connection';
COMMENT ON COLUMN public.profiles.connected_providers IS 'List of connected third-party OAuth providers (e.g. google)';

-- -------------------------------------------------------------
-- 2. Customers Table (Sales Reps' Clients)
-- -------------------------------------------------------------
CREATE TABLE public.customers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    nickname TEXT,
    avatar_url TEXT,
    phone TEXT,
    email TEXT,
    tags TEXT[] DEFAULT '{}'::TEXT[] NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE INDEX idx_customers_profile_id ON public.customers(profile_id);
COMMENT ON TABLE public.customers IS 'Stores customer profiles belonging to sales representatives.';

-- -------------------------------------------------------------
-- 3. Reminders Table (Voice Notes, AI Summaries & Schedules)
-- -------------------------------------------------------------
CREATE TABLE public.reminders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE NOT NULL,
    raw_transcript TEXT,
    ai_summary TEXT,
    remind_at TIMESTAMPTZ,
    is_completed BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE INDEX idx_reminders_customer_id ON public.reminders(customer_id);
COMMENT ON TABLE public.reminders IS 'Stores transcripts from voice notes, AI summaries, and scheduled reminders.';

-- -------------------------------------------------------------
-- Triggers for auto-updating updated_at columns
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to tables
CREATE TRIGGER trigger_update_profiles_timestamp
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trigger_update_customers_timestamp
    BEFORE UPDATE ON public.customers
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trigger_update_reminders_timestamp
    BEFORE UPDATE ON public.reminders
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- -------------------------------------------------------------
-- Trigger to automatically create profile on auth signup
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    initial_provider TEXT;
    is_google BOOLEAN := FALSE;
    providers_list TEXT[] := '{}';
BEGIN
    initial_provider := COALESCE(NEW.raw_app_meta_data->>'provider', 'email');
    
    IF initial_provider = 'google' THEN
        is_google := TRUE;
        providers_list := ARRAY['google'];
    END IF;

    INSERT INTO public.profiles (
        id, 
        email, 
        full_name, 
        role, 
        status,
        team_name,
        is_google_connected, 
        connected_providers
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'New Sales Rep'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'agent'),
        COALESCE(NEW.raw_user_meta_data->>'status', 'active'),
        COALESCE(NEW.raw_user_meta_data->>'team_name', '國泰台北第一通訊處'),
        is_google,
        providers_list
    )
    ON CONFLICT (id) DO UPDATE SET
        role = EXCLUDED.role,
        status = EXCLUDED.status,
        team_name = EXCLUDED.team_name,
        is_google_connected = EXCLUDED.is_google_connected,
        connected_providers = EXCLUDED.connected_providers;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- -------------------------------------------------------------
-- Row Level Security (RLS) Configuration
-- -------------------------------------------------------------

-- Enable RLS for all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------
-- RLS Policies
-- -------------------------------------------------------------

-- Profiles Policies
CREATE POLICY "Users can view their own profile" 
    ON public.profiles FOR SELECT 
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
    ON public.profiles FOR UPDATE 
    USING (auth.uid() = id);

-- Customers Policies
CREATE POLICY "Users can view their own customers" 
    ON public.customers FOR SELECT 
    USING (auth.uid() = profile_id);

CREATE POLICY "Users can insert their own customers" 
    ON public.customers FOR INSERT 
    WITH CHECK (auth.uid() = profile_id);

CREATE POLICY "Users can update their own customers" 
    ON public.customers FOR UPDATE 
    USING (auth.uid() = profile_id)
    WITH CHECK (auth.uid() = profile_id);

CREATE POLICY "Users can delete their own customers" 
    ON public.customers FOR DELETE 
    USING (auth.uid() = profile_id);

-- Reminders Policies
CREATE POLICY "Users can view reminders for their own customers" 
    ON public.reminders FOR SELECT 
    USING (
        auth.uid() = (
            SELECT profile_id 
            FROM public.customers 
            WHERE customers.id = reminders.customer_id
        )
    );

CREATE POLICY "Users can insert reminders for their own customers" 
    ON public.reminders FOR INSERT 
    WITH CHECK (
        auth.uid() = (
            SELECT profile_id 
            FROM public.customers 
            WHERE customers.id = customer_id
        )
    );

CREATE POLICY "Users can update reminders for their own customers" 
    ON public.reminders FOR UPDATE 
    USING (
        auth.uid() = (
            SELECT profile_id 
            FROM public.customers 
            WHERE customers.id = reminders.customer_id
        )
    )
    WITH CHECK (
        auth.uid() = (
            SELECT profile_id 
            FROM public.customers 
            WHERE customers.id = customer_id
        )
    );

CREATE POLICY "Users can delete reminders for their own customers" 
    ON public.reminders FOR DELETE 
    USING (
        auth.uid() = (
            SELECT profile_id 
            FROM public.customers 
            WHERE customers.id = reminders.customer_id
        )
    );

-- =============================================================
-- Schema Upgrades for Existing Databases (Idempotent)
-- =============================================================
ALTER TABLE public.profiles 
    ADD COLUMN IF NOT EXISTS avatar_url TEXT,
    ADD COLUMN IF NOT EXISTS phone TEXT,
    ADD COLUMN IF NOT EXISTS company TEXT,
    ADD COLUMN IF NOT EXISTS job_title TEXT,
    ADD COLUMN IF NOT EXISTS website TEXT,
    ADD COLUMN IF NOT EXISTS address TEXT,
    ADD COLUMN IF NOT EXISTS bio TEXT;

-- =============================================================
-- 4. Storage configuration (Buckets & RLS Policies)
-- =============================================================

-- 建立儲存桶 (customer-photos 與 avatars)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('customer-photos', 'customer-photos', true),
       ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 啟用 RLS 政策 (依安全限制隔離，使用者僅能新增/更新/刪除屬於自己 UID 資料夾底下的照片)
-- customer-photos Policies
CREATE POLICY "Public Read Access for Customer Photos" ON storage.objects
    FOR SELECT USING (bucket_id = 'customer-photos');

CREATE POLICY "Authenticated Insert Access for Customer Photos" ON storage.objects
    FOR INSERT TO authenticated WITH CHECK (
        bucket_id = 'customer-photos' AND 
        (select auth.uid()::text) = (storage.foldername(name))[1]
    );

CREATE POLICY "Authenticated Update Access for Customer Photos" ON storage.objects
    FOR UPDATE TO authenticated USING (
        bucket_id = 'customer-photos' AND 
        (select auth.uid()::text) = (storage.foldername(name))[1]
    );

CREATE POLICY "Authenticated Delete Access for Customer Photos" ON storage.objects
    FOR DELETE TO authenticated USING (
        bucket_id = 'customer-photos' AND 
        (select auth.uid()::text) = (storage.foldername(name))[1]
    );

-- avatars Policies
CREATE POLICY "Public Read Access for Avatars" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Authenticated Insert Access for Avatars" ON storage.objects
    FOR INSERT TO authenticated WITH CHECK (
        bucket_id = 'avatars' AND 
        (select auth.uid()::text) = (storage.foldername(name))[1]
    );

CREATE POLICY "Authenticated Update Access for Avatars" ON storage.objects
    FOR UPDATE TO authenticated USING (
        bucket_id = 'avatars' AND 
        (select auth.uid()::text) = (storage.foldername(name))[1]
    );

CREATE POLICY "Authenticated Delete Access for Avatars" ON storage.objects
    FOR DELETE TO authenticated USING (
        bucket_id = 'avatars' AND 
        (select auth.uid()::text) = (storage.foldername(name))[1]
    );

-- =============================================================
-- 5. Data Trash Bin & Photo Storage Auto-Cleanup Configuration
-- =============================================================

-- Add deleted_at fields for soft deletion
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE public.reminders ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Trigger to delete customer photo from storage on physical hard delete
CREATE OR REPLACE FUNCTION public.delete_customer_photo_on_delete()
RETURNS TRIGGER AS $$
DECLARE
    file_path TEXT;
BEGIN
    IF OLD.avatar_url IS NOT NULL AND OLD.avatar_url LIKE '%/customer-photos/%' THEN
        -- Extract the path after 'customer-photos/'
        file_path := split_part(OLD.avatar_url, '/customer-photos/', 2);
        IF file_path IS NOT NULL AND file_path <> '' THEN
            DELETE FROM storage.objects 
            WHERE bucket_id = 'customer-photos' 
              AND name = file_path;
        END IF;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trigger_delete_customer_photo
    AFTER DELETE ON public.customers
    FOR EACH ROW
    EXECUTE FUNCTION public.delete_customer_photo_on_delete();

-- Trigger to delete old customer photo when updated or cleared
CREATE OR REPLACE FUNCTION public.delete_old_customer_photo_on_update()
RETURNS TRIGGER AS $$
DECLARE
    old_file_path TEXT;
BEGIN
    IF OLD.avatar_url IS NOT NULL 
       AND OLD.avatar_url LIKE '%/customer-photos/%' 
       AND (NEW.avatar_url IS NULL OR NEW.avatar_url <> OLD.avatar_url) THEN
        
        old_file_path := split_part(OLD.avatar_url, '/customer-photos/', 2);
        IF old_file_path IS NOT NULL AND old_file_path <> '' THEN
            DELETE FROM storage.objects 
            WHERE bucket_id = 'customer-photos' 
              AND name = old_file_path;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trigger_delete_old_customer_photo
    AFTER UPDATE ON public.customers
    FOR EACH ROW
    EXECUTE FUNCTION public.delete_old_customer_photo_on_update();

-- Trigger to delete old profile avatar when updated or cleared
CREATE OR REPLACE FUNCTION public.delete_old_avatar_on_update()
RETURNS TRIGGER AS $$
DECLARE
    old_file_path TEXT;
BEGIN
    IF OLD.avatar_url IS NOT NULL 
       AND OLD.avatar_url LIKE '%/avatars/%' 
       AND (NEW.avatar_url IS NULL OR NEW.avatar_url <> OLD.avatar_url) THEN
        
        old_file_path := split_part(OLD.avatar_url, '/avatars/', 2);
        IF old_file_path IS NOT NULL AND old_file_path <> '' THEN
            DELETE FROM storage.objects 
            WHERE bucket_id = 'avatars' 
              AND name = old_file_path;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trigger_delete_old_avatar
    AFTER UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.delete_old_avatar_on_update();

-- Enable pg_cron and schedule daily purge of soft-deleted data (> 30 days)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule daily midnight purge (database local timezone or UTC depending on server setting)
SELECT cron.schedule(
    'purge-deleted-data-daily',
    '0 0 * * *', -- Everyday at 00:00 (midnight)
    $$
    DELETE FROM public.customers WHERE deleted_at < NOW() - INTERVAL '30 days';
    DELETE FROM public.reminders WHERE deleted_at < NOW() - INTERVAL '30 days';
    $$
);

-- =============================================================
-- Phase 1.5 Database Upgrades (Categorized Tags & Visit Projects)
-- =============================================================

-- 1. Tag Categories Table
CREATE TABLE IF NOT EXISTS public.tag_categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    color_code TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS and add Policies for tag_categories
ALTER TABLE public.tag_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to tag_categories" ON public.tag_categories 
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated insert to tag_categories" ON public.tag_categories 
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated update to tag_categories" ON public.tag_categories 
    FOR UPDATE TO authenticated USING (true);

-- Seed pre-defined Tag Categories
INSERT INTO public.tag_categories (name, color_code)
VALUES 
    ('客戶身分', 'blue'),
    ('已購險種', 'green'),
    ('生活興趣', 'orange'),
    ('健康與體況', 'pink'),
    ('跟進狀態', 'purple')
ON CONFLICT (name) DO NOTHING;

-- 2. Tags Table
CREATE TABLE IF NOT EXISTS public.tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES public.tag_categories(id) ON DELETE CASCADE,
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT unique_tags_category_name UNIQUE (category_id, name)
);

-- Enable RLS and add Policies for tags
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to tags" ON public.tags 
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated insert to tags" ON public.tags 
    FOR INSERT TO authenticated WITH CHECK (true);

-- 3. Customer Tags Junction Table
CREATE TABLE IF NOT EXISTS public.customer_tags (
    customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES public.tags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (customer_id, tag_id)
);

-- Enable RLS and add Policies for customer_tags
ALTER TABLE public.customer_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view customer_tags for their customers" ON public.customer_tags 
    FOR SELECT USING (
        auth.uid() = (SELECT profile_id FROM public.customers WHERE id = customer_id)
    );
    
CREATE POLICY "Users can insert customer_tags for their customers" ON public.customer_tags 
    FOR INSERT TO authenticated WITH CHECK (
        auth.uid() = (SELECT profile_id FROM public.customers WHERE id = customer_id)
    );
    
CREATE POLICY "Users can delete customer_tags for their customers" ON public.customer_tags 
    FOR DELETE TO authenticated USING (
        auth.uid() = (SELECT profile_id FROM public.customers WHERE id = customer_id)
    );

-- 4. Trigger to sync customer tags array column to tags and customer_tags tables
CREATE OR REPLACE FUNCTION public.sync_customer_tags()
RETURNS TRIGGER AS $$
DECLARE
    tag_name TEXT;
    cat_id UUID;
    t_id UUID;
BEGIN
    -- Delete relation links not present in the new tag array
    DELETE FROM public.customer_tags
    WHERE customer_id = NEW.id
      AND tag_id NOT IN (
          SELECT id FROM public.tags WHERE name = ANY(NEW.tags)
      );

    -- Insert/link each tag in the new array
    IF NEW.tags IS NOT NULL AND array_length(NEW.tags, 1) > 0 THEN
        FOREACH tag_name IN ARRAY NEW.tags LOOP
            tag_name := trim(tag_name);
            IF tag_name = '' THEN
                CONTINUE;
            END IF;

            -- Find existing tag
            SELECT id INTO t_id FROM public.tags WHERE name = tag_name LIMIT 1;
            
            -- Create tag if not exists
            IF t_id IS NULL THEN
                -- Category auto-mapping rules
                IF tag_name LIKE '%險' OR tag_name LIKE '%保單' OR tag_name LIKE '%規劃' OR tag_name LIKE '%儲蓄' THEN
                    SELECT id INTO cat_id FROM public.tag_categories WHERE name = '已購險種' LIMIT 1;
                ELSIF tag_name LIKE '%意願' OR tag_name LIKE '%簽單' OR tag_name LIKE '%跟進' OR tag_name = '已簽單' OR tag_name = '待跟進' THEN
                    SELECT id INTO cat_id FROM public.tag_categories WHERE name = '跟進狀態' LIMIT 1;
                ELSIF tag_name LIKE '%體況' OR tag_name LIKE '%病%' OR tag_name LIKE '%血壓' OR tag_name LIKE '%手術' OR tag_name LIKE '%健康' OR tag_name LIKE '%史' THEN
                    SELECT id INTO cat_id FROM public.tag_categories WHERE name = '健康與體況' LIMIT 1;
                ELSIF tag_name LIKE '%愛%' OR tag_name LIKE '%運動%' OR tag_name LIKE '%茶%' OR tag_name LIKE '%玩%' OR tag_name LIKE '%露營%' OR tag_name LIKE '%爬山%' OR tag_name LIKE '%旅遊%' THEN
                    SELECT id INTO cat_id FROM public.tag_categories WHERE name = '生活興趣' LIMIT 1;
                ELSE
                    SELECT id INTO cat_id FROM public.tag_categories WHERE name = '客戶身分' LIMIT 1;
                END IF;

                -- Category fallback
                IF cat_id IS NULL THEN
                    SELECT id INTO cat_id FROM public.tag_categories WHERE name = '客戶身分' LIMIT 1;
                END IF;

                -- Insert the tag
                INSERT INTO public.tags (category_id, name)
                VALUES (cat_id, tag_name)
                ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
                RETURNING id INTO t_id;

                -- Fallback lookup if needed
                IF t_id IS NULL THEN
                    SELECT id INTO t_id FROM public.tags WHERE name = tag_name LIMIT 1;
                END IF;
            END IF;

            -- Insert junction relation
            IF t_id IS NOT NULL THEN
                INSERT INTO public.customer_tags (customer_id, tag_id)
                VALUES (NEW.id, t_id)
                ON CONFLICT (customer_id, tag_id) DO NOTHING;
            END IF;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind trigger to customers table
DROP TRIGGER IF EXISTS trigger_sync_customer_tags ON public.customers;
CREATE TRIGGER trigger_sync_customer_tags
    AFTER INSERT OR UPDATE OF tags ON public.customers
    FOR EACH ROW EXECUTE FUNCTION public.sync_customer_tags();

-- Migrate existing customers' tags to populate the new tables
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT id, tags FROM public.customers LOOP
        UPDATE public.customers SET tags = r.tags WHERE id = r.id;
    END LOOP;
END;
$$;

-- 5. Visit Projects Table (Project-based Visit Todo List)
CREATE TABLE IF NOT EXISTS public.visit_projects (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    purpose TEXT NOT NULL,
    is_completed BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_visit_projects_profile_id ON public.visit_projects(profile_id);

-- Bind updated_at trigger to visit_projects
DROP TRIGGER IF EXISTS trigger_update_visit_projects_timestamp ON public.visit_projects;
CREATE TRIGGER trigger_update_visit_projects_timestamp
    BEFORE UPDATE ON public.visit_projects
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Enable RLS for visit_projects
ALTER TABLE public.visit_projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own visit_projects" ON public.visit_projects
    FOR SELECT USING (auth.uid() = profile_id);

CREATE POLICY "Users can insert their own visit_projects" ON public.visit_projects
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = profile_id);

CREATE POLICY "Users can update their own visit_projects" ON public.visit_projects
    FOR UPDATE TO authenticated USING (auth.uid() = profile_id) WITH CHECK (auth.uid() = profile_id);

CREATE POLICY "Users can delete their own visit_projects" ON public.visit_projects
    FOR DELETE TO authenticated USING (auth.uid() = profile_id);

-- 6. Visit Project Customers Table ( Checklist Checklist Relation )
CREATE TABLE IF NOT EXISTS public.visit_project_customers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    visit_project_id UUID REFERENCES public.visit_projects(id) ON DELETE CASCADE NOT NULL,
    customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE NOT NULL,
    is_visited BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_vpc_project_id ON public.visit_project_customers(visit_project_id);
CREATE INDEX IF NOT EXISTS idx_vpc_customer_id ON public.visit_project_customers(customer_id);

-- Enable RLS for visit_project_customers
ALTER TABLE public.visit_project_customers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view visit_project_customers for their projects" ON public.visit_project_customers
    FOR SELECT USING (
        auth.uid() = (SELECT profile_id FROM public.visit_projects WHERE id = visit_project_id)
    );

CREATE POLICY "Users can insert visit_project_customers for their projects" ON public.visit_project_customers
    FOR INSERT TO authenticated WITH CHECK (
        auth.uid() = (SELECT profile_id FROM public.visit_projects WHERE id = visit_project_id)
    );

CREATE POLICY "Users can update visit_project_customers for their projects" ON public.visit_project_customers
    FOR UPDATE TO authenticated USING (
        auth.uid() = (SELECT profile_id FROM public.visit_projects WHERE id = visit_project_id)
    ) WITH CHECK (
        auth.uid() = (SELECT profile_id FROM public.visit_projects WHERE id = visit_project_id)
    );

CREATE POLICY "Users can delete visit_project_customers for their projects" ON public.visit_project_customers
    FOR DELETE TO authenticated USING (
        auth.uid() = (SELECT profile_id FROM public.visit_projects WHERE id = visit_project_id)
    );

-- =============================================================
-- 7. Schedule Events Table (Calendar Revamp - Phase 5)
-- =============================================================
CREATE TABLE IF NOT EXISTS public.schedule_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE, -- NULLable for personal events
    title TEXT NOT NULL,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    location TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    tag TEXT, -- 自訂標籤名稱
    event_type TEXT DEFAULT 'personal', -- e.g., 'personal', 'meeting', 'visit', 'reminder'
    is_completed BOOLEAN DEFAULT FALSE NOT NULL,
    google_event_id TEXT,
    google_calendar_id TEXT,
    sync_status TEXT DEFAULT 'local_only',
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_schedule_events_profile_id ON public.schedule_events(profile_id);
CREATE INDEX IF NOT EXISTS idx_schedule_events_customer_id ON public.schedule_events(customer_id);

-- Bind updated_at trigger to schedule_events
DROP TRIGGER IF EXISTS trigger_update_schedule_events_timestamp ON public.schedule_events;
CREATE TRIGGER trigger_update_schedule_events_timestamp
    BEFORE UPDATE ON public.schedule_events
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Enable RLS for schedule_events
ALTER TABLE public.schedule_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own schedule_events" ON public.schedule_events
    FOR SELECT USING (auth.uid() = profile_id);

CREATE POLICY "Users can insert their own schedule_events" ON public.schedule_events
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = profile_id);

CREATE POLICY "Users can update their own schedule_events" ON public.schedule_events
    FOR UPDATE TO authenticated USING (auth.uid() = profile_id) WITH CHECK (auth.uid() = profile_id);

CREATE POLICY "Users can delete their own schedule_events" ON public.schedule_events
    FOR DELETE TO authenticated USING (auth.uid() = profile_id);

-- =============================================================
-- 8. Insurance News Topics & Articles Table (Phase 7)
-- =============================================================

-- Insurance News Topics Table
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

-- Insurance News Articles Table
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

CREATE INDEX IF NOT EXISTS idx_insurance_news_topics_date ON public.insurance_news_topics(publish_date DESC);
CREATE INDEX IF NOT EXISTS idx_insurance_news_articles_topic_id ON public.insurance_news_articles(topic_id);

-- Enable RLS
ALTER TABLE public.insurance_news_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insurance_news_articles ENABLE ROW LEVEL SECURITY;

-- Public RLS Policies (Read Access)
DROP POLICY IF EXISTS "Allow public read access for insurance_news_topics" ON public.insurance_news_topics;
CREATE POLICY "Allow public read access for insurance_news_topics"
    ON public.insurance_news_topics FOR SELECT
    TO public
    USING (true);

DROP POLICY IF EXISTS "Allow public read access for insurance_news_articles" ON public.insurance_news_articles;
CREATE POLICY "Allow public read access for insurance_news_articles"
    ON public.insurance_news_articles FOR SELECT
    TO public
    USING (true);

-- -------------------------------------------------------------
-- 10. Notifications Table (Bidirectional Notification Center)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    sender_name TEXT DEFAULT '系統',
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'system_notice' CHECK (type IN ('customer_reassigned', 'manager_task_note', 'ai_smart_alert', 'system_notice')),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    target_customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notifications_profile_id ON public.notifications(profile_id);
COMMENT ON TABLE public.notifications IS 'Stores user notifications for assignments, task notes, AI alerts, and system notices';

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own notifications') THEN
        CREATE POLICY "Users can view their own notifications"
            ON public.notifications FOR SELECT
            USING (auth.uid() = profile_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update their own notifications') THEN
        CREATE POLICY "Users can update their own notifications"
            ON public.notifications FOR UPDATE
            USING (auth.uid() = profile_id);
    END IF;
-- -------------------------------------------------------------
-- 11. Phase 1 Database Hardening (Integrity & Performance Indexes)
-- -------------------------------------------------------------

-- Constraints & Integrity Checks
ALTER TABLE public.insurance_news_articles DROP CONSTRAINT IF EXISTS unique_insurance_news_articles_source_url;
ALTER TABLE public.insurance_news_articles ADD CONSTRAINT unique_insurance_news_articles_source_url UNIQUE (source_url);

ALTER TABLE public.policy_clauses DROP CONSTRAINT IF EXISTS unique_product_name;
ALTER TABLE public.policy_clauses DROP CONSTRAINT IF EXISTS unique_policy_clauses_company_product;
ALTER TABLE public.policy_clauses ADD CONSTRAINT unique_policy_clauses_company_product UNIQUE (company_name, product_name);

ALTER TABLE public.schedule_events DROP CONSTRAINT IF EXISTS chk_schedule_events_time_order;
ALTER TABLE public.schedule_events ADD CONSTRAINT chk_schedule_events_time_order CHECK (end_at >= start_at);

ALTER TABLE public.schedule_events DROP CONSTRAINT IF EXISTS chk_schedule_events_event_type;
ALTER TABLE public.schedule_events ADD CONSTRAINT chk_schedule_events_event_type 
    CHECK (event_type IN ('personal', 'customer_visit', 'meeting', 'follow_up', 'general'));

ALTER TABLE public.customer_relationships DROP CONSTRAINT IF EXISTS unique_customer_relationship;
ALTER TABLE public.customer_relationships ADD CONSTRAINT unique_customer_relationship 
    UNIQUE (user_id, source_customer_id, target_customer_id, relationship_type);

ALTER TABLE public.visit_project_customers DROP CONSTRAINT IF EXISTS unique_visit_project_customer;
ALTER TABLE public.visit_project_customers ADD CONSTRAINT unique_visit_project_customer 
    UNIQUE (visit_project_id, customer_id);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_customers_deleted_at ON public.customers(deleted_at);
CREATE INDEX IF NOT EXISTS idx_customers_referral_source_id ON public.customers(referral_source_id);
CREATE INDEX IF NOT EXISTS idx_reminders_deleted_at ON public.reminders(deleted_at);
CREATE INDEX IF NOT EXISTS idx_reminders_remind_at ON public.reminders(remind_at);
CREATE INDEX IF NOT EXISTS idx_schedule_events_start_at ON public.schedule_events(start_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_schedule_events_google_sync 
    ON public.schedule_events(profile_id, google_calendar_id, google_event_id) 
    WHERE google_event_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_cr_user_id ON public.customer_relationships(user_id);
CREATE INDEX IF NOT EXISTS idx_cr_source ON public.customer_relationships(source_customer_id);
CREATE INDEX IF NOT EXISTS idx_cr_target ON public.customer_relationships(target_customer_id);

CREATE INDEX IF NOT EXISTS idx_customer_tags_tag_id ON public.customer_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_tags_category_id ON public.tags(category_id);
CREATE INDEX IF NOT EXISTS idx_policy_clauses_category ON public.policy_clauses(category);

-- RBAC Admin Helper Function
CREATE OR REPLACE FUNCTION public.is_admin_or_dev()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role IN ('admin', 'dev')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;


