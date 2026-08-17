-- ============================================================================
-- Migration: 20260817_database_hardening_stage2.sql
-- Description: Phase 2 Database Hardening (Safety, Triggers, Constraints & RLS)
-- Includes:
--   1. Data Integrity Constraints (profiles role/status, tags compound unique, anti-self-link, lat/lng)
--   2. Universal updated_at Triggers (profiles, customers, reminders, visit_projects, schedule_events, etc.)
--   3. Comprehensive Row Level Security (RLS) Policies across all tables
--   4. Admin / Dev bypass support via is_admin_or_dev()
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Data Integrity Checks & Constraint Hardening
-- ----------------------------------------------------------------------------

-- A. profiles: Validate role and status values
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_profiles_role'
    ) THEN
        ALTER TABLE public.profiles 
            ADD CONSTRAINT chk_profiles_role 
            CHECK (role IN ('agent', 'manager', 'admin', 'dev'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_profiles_status'
    ) THEN
        ALTER TABLE public.profiles 
            ADD CONSTRAINT chk_profiles_status 
            CHECK (status IN ('active', 'pending', 'deleted', 'suspended'));
    END IF;
END $$;

-- B. tags: Loosen global name UNIQUE to compound (category_id, name)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'tags_name_key'
    ) THEN
        ALTER TABLE public.tags DROP CONSTRAINT tags_name_key;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'unique_tags_category_name'
    ) THEN
        ALTER TABLE public.tags 
            ADD CONSTRAINT unique_tags_category_name UNIQUE (category_id, name);
    END IF;
END $$;

-- C. customer_relationships: Prevent self-linking (source_id cannot equal target_id)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_cr_no_self_link'
    ) THEN
        ALTER TABLE public.customer_relationships 
            ADD CONSTRAINT chk_cr_no_self_link 
            CHECK (source_customer_id <> target_customer_id);
    END IF;
END $$;

-- D. schedule_events: Latitude and Longitude range constraints
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_schedule_events_lat'
    ) THEN
        ALTER TABLE public.schedule_events 
            ADD CONSTRAINT chk_schedule_events_lat 
            CHECK (latitude IS NULL OR (latitude >= -90 AND latitude <= 90));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_schedule_events_lng'
    ) THEN
        ALTER TABLE public.schedule_events 
            ADD CONSTRAINT chk_schedule_events_lng 
            CHECK (longitude IS NULL OR (longitude >= -180 AND longitude <= 180));
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 2. Universal Auto-Updating Timestamps Triggers
-- ----------------------------------------------------------------------------

-- Ensure handle_updated_at() exists
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to core business tables
DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY['profiles', 'customers', 'reminders', 'visit_projects', 'schedule_events', 'customer_relationships', 'policy_clauses'];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = tbl AND column_name = 'updated_at'
        ) THEN
            EXECUTE format('DROP TRIGGER IF EXISTS trigger_update_%I_timestamp ON public.%I;', tbl, tbl);
            EXECUTE format('CREATE TRIGGER trigger_update_%I_timestamp BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();', tbl, tbl);
        END IF;
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 3. Row Level Security (RLS) Policies Hardening
-- ----------------------------------------------------------------------------

-- Helper function check
CREATE OR REPLACE FUNCTION public.is_admin_or_dev()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role IN ('admin', 'dev')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- A. profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles are readable by authenticated users" ON public.profiles;
CREATE POLICY "Profiles are readable by authenticated users"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Users can update own profile or admin/dev" ON public.profiles;
CREATE POLICY "Users can update own profile or admin/dev"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (id = auth.uid() OR public.is_admin_or_dev())
    WITH CHECK (id = auth.uid() OR public.is_admin_or_dev());

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT
    TO authenticated
    WITH CHECK (id = auth.uid() OR public.is_admin_or_dev());

-- B. customers
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Agents can manage own customers" ON public.customers;
CREATE POLICY "Agents can manage own customers"
    ON public.customers FOR ALL
    TO authenticated
    USING (profile_id = auth.uid() OR public.is_admin_or_dev())
    WITH CHECK (profile_id = auth.uid() OR public.is_admin_or_dev());

-- C. reminders
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Agents can manage own reminders" ON public.reminders;
CREATE POLICY "Agents can manage own reminders"
    ON public.reminders FOR ALL
    TO authenticated
    USING (
        customer_id IN (SELECT id FROM public.customers WHERE profile_id = auth.uid())
        OR public.is_admin_or_dev()
    )
    WITH CHECK (
        customer_id IN (SELECT id FROM public.customers WHERE profile_id = auth.uid())
        OR public.is_admin_or_dev()
    );

-- D. visit_logs
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'visit_logs') THEN
        ALTER TABLE public.visit_logs ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Agents can manage own visit logs" ON public.visit_logs;
        CREATE POLICY "Agents can manage own visit logs"
            ON public.visit_logs FOR ALL
            TO authenticated
            USING (
                user_id = auth.uid() 
                OR (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'visit_logs' AND column_name = 'profile_id') AND profile_id = auth.uid())
                OR public.is_admin_or_dev()
            )
            WITH CHECK (
                user_id = auth.uid() 
                OR (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'visit_logs' AND column_name = 'profile_id') AND profile_id = auth.uid())
                OR public.is_admin_or_dev()
            );
    END IF;
END $$;

-- E. schedule_events
ALTER TABLE public.schedule_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Agents can manage own schedule events" ON public.schedule_events;
CREATE POLICY "Agents can manage own schedule events"
    ON public.schedule_events FOR ALL
    TO authenticated
    USING (profile_id = auth.uid() OR public.is_admin_or_dev())
    WITH CHECK (profile_id = auth.uid() OR public.is_admin_or_dev());

-- F. visit_projects & visit_project_customers
ALTER TABLE public.visit_projects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Agents can manage own visit projects" ON public.visit_projects;
CREATE POLICY "Agents can manage own visit projects"
    ON public.visit_projects FOR ALL
    TO authenticated
    USING (profile_id = auth.uid() OR public.is_admin_or_dev())
    WITH CHECK (profile_id = auth.uid() OR public.is_admin_or_dev());

ALTER TABLE public.visit_project_customers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Agents can manage own visit project customers" ON public.visit_project_customers;
CREATE POLICY "Agents can manage own visit project customers"
    ON public.visit_project_customers FOR ALL
    TO authenticated
    USING (
        visit_project_id IN (SELECT id FROM public.visit_projects WHERE profile_id = auth.uid())
        OR public.is_admin_or_dev()
    )
    WITH CHECK (
        visit_project_id IN (SELECT id FROM public.visit_projects WHERE profile_id = auth.uid())
        OR public.is_admin_or_dev()
    );

-- G. customer_relationships
ALTER TABLE public.customer_relationships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Agents can manage own customer relationships" ON public.customer_relationships;
CREATE POLICY "Agents can manage own customer relationships"
    ON public.customer_relationships FOR ALL
    TO authenticated
    USING (user_id = auth.uid() OR public.is_admin_or_dev())
    WITH CHECK (user_id = auth.uid() OR public.is_admin_or_dev());

-- H. Shared/Public Knowledge & Tag Tables (Readable by all authenticated, manageable by admin/dev)
ALTER TABLE public.policy_clauses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Policy clauses readable by authenticated" ON public.policy_clauses;
CREATE POLICY "Policy clauses readable by authenticated"
    ON public.policy_clauses FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Policy clauses manageable by admin/dev" ON public.policy_clauses;
CREATE POLICY "Policy clauses manageable by admin/dev"
    ON public.policy_clauses FOR ALL
    TO authenticated
    USING (public.is_admin_or_dev())
    WITH CHECK (public.is_admin_or_dev());

ALTER TABLE public.insurance_news_articles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "News articles readable by authenticated" ON public.insurance_news_articles;
CREATE POLICY "News articles readable by authenticated"
    ON public.insurance_news_articles FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "News articles manageable by admin/dev" ON public.insurance_news_articles;
CREATE POLICY "News articles manageable by admin/dev"
    ON public.insurance_news_articles FOR ALL
    TO authenticated
    USING (public.is_admin_or_dev())
    WITH CHECK (public.is_admin_or_dev());

ALTER TABLE public.insurance_news_topics ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "News topics readable by authenticated" ON public.insurance_news_topics;
CREATE POLICY "News topics readable by authenticated"
    ON public.insurance_news_topics FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "News topics manageable by admin/dev" ON public.insurance_news_topics;
CREATE POLICY "News topics manageable by admin/dev"
    ON public.insurance_news_topics FOR ALL
    TO authenticated
    USING (public.is_admin_or_dev())
    WITH CHECK (public.is_admin_or_dev());

ALTER TABLE public.tag_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Tag categories readable by authenticated" ON public.tag_categories;
CREATE POLICY "Tag categories readable by authenticated"
    ON public.tag_categories FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Tag categories manageable by admin/dev" ON public.tag_categories;
CREATE POLICY "Tag categories manageable by admin/dev"
    ON public.tag_categories FOR ALL
    TO authenticated
    USING (public.is_admin_or_dev())
    WITH CHECK (public.is_admin_or_dev());

ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Tags readable by authenticated" ON public.tags;
CREATE POLICY "Tags readable by authenticated"
    ON public.tags FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Tags manageable by authenticated" ON public.tags;
CREATE POLICY "Tags manageable by authenticated"
    ON public.tags FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

ALTER TABLE public.customer_tags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Customer tags readable and manageable by agent" ON public.customer_tags;
CREATE POLICY "Customer tags readable and manageable by agent"
    ON public.customer_tags FOR ALL
    TO authenticated
    USING (
        customer_id IN (SELECT id FROM public.customers WHERE profile_id = auth.uid())
        OR public.is_admin_or_dev()
    )
    WITH CHECK (
        customer_id IN (SELECT id FROM public.customers WHERE profile_id = auth.uid())
        OR public.is_admin_or_dev()
    );
