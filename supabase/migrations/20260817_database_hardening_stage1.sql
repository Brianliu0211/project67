-- ============================================================================
-- Migration: 20260817_database_hardening_stage1.sql
-- Description: Phase 1 Database Hardening (Zero-Breaking)
-- Includes:
--   1. Data Cleanup & Deduplication (Prevent migration failure)
--   2. Constraints & Integrity Checks (CHECK, UNIQUE, Multi-column unique)
--   3. Foreign Key & Query Performance Indexes (B-Tree)
--   4. Universal auto-updating timestamps (handle_updated_at Trigger)
--   5. Multi-tenant & RBAC RLS Safety Hardening
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Data Cleaning & Deduplication (Pre-requisite for Constraints)
-- ----------------------------------------------------------------------------

-- A. Deduplicate insurance_news_articles by source_url (keep latest created/id)
DELETE FROM public.insurance_news_articles a
USING public.insurance_news_articles b
WHERE a.source_url = b.source_url 
  AND a.id < b.id;

-- B. Fix any invalid schedule_events where end_at < start_at (shift end_at to start_at + 1 hour)
UPDATE public.schedule_events
SET end_at = start_at + INTERVAL '1 hour'
WHERE end_at < start_at;

-- ----------------------------------------------------------------------------
-- 2. Constraints & Integrity Checks
-- ----------------------------------------------------------------------------

-- A. insurance_news_articles: Unique source_url
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'unique_insurance_news_articles_source_url'
    ) THEN
        ALTER TABLE public.insurance_news_articles 
            ADD CONSTRAINT unique_insurance_news_articles_source_url UNIQUE (source_url);
    END IF;
END $$;

-- B. policy_clauses: Change single product_name UNIQUE to compound (company_name, product_name)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'unique_product_name'
    ) THEN
        ALTER TABLE public.policy_clauses DROP CONSTRAINT unique_product_name;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'unique_policy_clauses_company_product'
    ) THEN
        ALTER TABLE public.policy_clauses 
            ADD CONSTRAINT unique_policy_clauses_company_product UNIQUE (company_name, product_name);
    END IF;
END $$;

-- C. schedule_events: Time order & event_type checks
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_schedule_events_time_order'
    ) THEN
        ALTER TABLE public.schedule_events 
            ADD CONSTRAINT chk_schedule_events_time_order CHECK (end_at >= start_at);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_schedule_events_event_type'
    ) THEN
        ALTER TABLE public.schedule_events 
            ADD CONSTRAINT chk_schedule_events_event_type 
            CHECK (event_type IN ('personal', 'customer_visit', 'meeting', 'follow_up', 'general'));
    END IF;
END $$;

-- D. customer_relationships: Prevent duplicate connections
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'unique_customer_relationship'
    ) THEN
        ALTER TABLE public.customer_relationships 
            ADD CONSTRAINT unique_customer_relationship 
            UNIQUE (user_id, source_customer_id, target_customer_id, relationship_type);
    END IF;
END $$;

-- E. visit_project_customers: Prevent duplicate customer in same project
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'unique_visit_project_customer'
    ) THEN
        ALTER TABLE public.visit_project_customers 
            ADD CONSTRAINT unique_visit_project_customer 
            UNIQUE (visit_project_id, customer_id);
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 3. Performance Indexes (Foreign Keys & High-Frequency Filters)
-- ----------------------------------------------------------------------------

-- Customers & Reminders Soft Delete / Search Indexes
CREATE INDEX IF NOT EXISTS idx_customers_deleted_at ON public.customers(deleted_at);
CREATE INDEX IF NOT EXISTS idx_customers_referral_source_id ON public.customers(referral_source_id);
CREATE INDEX IF NOT EXISTS idx_reminders_deleted_at ON public.reminders(deleted_at);
CREATE INDEX IF NOT EXISTS idx_reminders_remind_at ON public.reminders(remind_at);

-- Schedule Events
CREATE INDEX IF NOT EXISTS idx_schedule_events_start_at ON public.schedule_events(start_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_schedule_events_google_sync 
    ON public.schedule_events(profile_id, google_calendar_id, google_event_id) 
    WHERE google_event_id IS NOT NULL;

-- Customer Relationships
CREATE INDEX IF NOT EXISTS idx_cr_user_id ON public.customer_relationships(user_id);
CREATE INDEX IF NOT EXISTS idx_cr_source ON public.customer_relationships(source_customer_id);
CREATE INDEX IF NOT EXISTS idx_cr_target ON public.customer_relationships(target_customer_id);

-- Tags & Policy Clauses
CREATE INDEX IF NOT EXISTS idx_customer_tags_tag_id ON public.customer_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_tags_category_id ON public.tags(category_id);
CREATE INDEX IF NOT EXISTS idx_policy_clauses_category ON public.policy_clauses(category);

-- ----------------------------------------------------------------------------
-- 4. Universal Auto-Updating Timestamps Trigger
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to news_rss_sources if column exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'news_rss_sources' AND column_name = 'updated_at'
    ) THEN
        DROP TRIGGER IF EXISTS trigger_update_news_rss_sources_timestamp ON public.news_rss_sources;
        CREATE TRIGGER trigger_update_news_rss_sources_timestamp
            BEFORE UPDATE ON public.news_rss_sources
            FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 5. Helper Function for Admin / Dev Bypass in RLS
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_admin_or_dev()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role IN ('admin', 'dev')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION public.is_admin_or_dev IS 'Returns true if current authenticated user has admin or dev role';
