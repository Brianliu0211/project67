-- ============================================================================
-- Migration: 20260818_database_hardening_final.sql
-- Single-responsibility Security Hardening & Zero-Breaking RBAC
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Profiles 欄位補齊 (方案 A) 與值域約束
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'agent',
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS team_id UUID DEFAULT 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::UUID,
  ADD COLUMN IF NOT EXISTS team_name TEXT DEFAULT '國泰台北第一通訊處',
  ADD COLUMN IF NOT EXISTS is_google_connected BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS connected_providers TEXT[] NOT NULL DEFAULT '{}'::TEXT[];

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_profiles_role;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_status_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_profiles_status;

ALTER TABLE public.profiles
  ADD CONSTRAINT chk_profiles_role CHECK (role IN ('agent', 'admin', 'dev')),
  ADD CONSTRAINT chk_profiles_status CHECK (status IN ('active', 'pending', 'deleted', 'suspended'));

-- ----------------------------------------------------------------------------
-- 2. 資料完整性約束 (Tags, Relationships, Schedule)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tags_name_key') THEN
    ALTER TABLE public.tags DROP CONSTRAINT tags_name_key;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'unique_tags_category_name') THEN
    ALTER TABLE public.tags ADD CONSTRAINT unique_tags_category_name UNIQUE (category_id, name);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_cr_no_self_link') THEN
    ALTER TABLE public.customer_relationships ADD CONSTRAINT chk_cr_no_self_link CHECK (source_customer_id <> target_customer_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_schedule_events_lat') THEN
    ALTER TABLE public.schedule_events ADD CONSTRAINT chk_schedule_events_lat CHECK (latitude IS NULL OR (latitude >= -90 AND latitude <= 90));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_schedule_events_lng') THEN
    ALTER TABLE public.schedule_events ADD CONSTRAINT chk_schedule_events_lng CHECK (longitude IS NULL OR (longitude >= -180 AND longitude <= 180));
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 3. 安全與輔助函式加固 (SECURITY DEFINER & Search Path)
-- ----------------------------------------------------------------------------

-- A. is_admin_or_dev 判斷函式
CREATE OR REPLACE FUNCTION public.is_admin_or_dev()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = (select auth.uid()) AND role IN ('admin', 'dev')
  );
$$;
REVOKE ALL ON FUNCTION public.is_admin_or_dev() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin_or_dev() TO authenticated;

-- B. 新用戶註冊 Trigger 函式 (自動以 agent / active 建立)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    role,
    status,
    team_id,
    team_name,
    is_google_connected,
    connected_providers
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'New Sales Rep'),
    'agent',
    'active',
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::UUID,
    '國泰台北第一通訊處',
    COALESCE(NEW.raw_app_meta_data->>'provider', 'email') = 'google',
    CASE WHEN COALESCE(NEW.raw_app_meta_data->>'provider', 'email') = 'google' THEN ARRAY['google'] ELSE '{}'::text[] END
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;

-- C. 防止一般用戶竄改角色/狀態/團隊/團隊名稱 Trigger 函式
CREATE OR REPLACE FUNCTION public.prevent_unprivileged_profile_security_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, auth
AS $$
BEGIN
  IF auth.uid() = NEW.id AND NOT public.is_admin_or_dev() THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'Only an administrator may change account role';
    END IF;
    IF NEW.status IS DISTINCT FROM OLD.status THEN
      RAISE EXCEPTION 'Only an administrator may change account status';
    END IF;
    IF NEW.team_id IS DISTINCT FROM OLD.team_id THEN
      RAISE EXCEPTION 'Only an administrator may change account team';
    END IF;
    IF NEW.team_name IS DISTINCT FROM OLD.team_name THEN
      RAISE EXCEPTION 'Only an administrator may change account team name';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.prevent_unprivileged_profile_security_changes() FROM PUBLIC;

DROP TRIGGER IF EXISTS prevent_unprivileged_profile_security_changes ON public.profiles;
CREATE TRIGGER prevent_unprivileged_profile_security_changes
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_unprivileged_profile_security_changes();

-- D. 其他 Trigger 函式 Search Path 與權限最小收束
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc'::text, NOW());
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.handle_updated_at() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.delete_customer_photo_on_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
  file_path TEXT;
BEGIN
  IF OLD.avatar_url IS NOT NULL AND OLD.avatar_url LIKE '%/customer-photos/%' THEN
    file_path := split_part(OLD.avatar_url, '/customer-photos/', 2);
    IF file_path IS NOT NULL AND file_path <> '' THEN
      DELETE FROM storage.objects WHERE bucket_id = 'customer-photos' AND name = file_path;
    END IF;
  END IF;
  RETURN OLD;
END;
$$;
REVOKE ALL ON FUNCTION public.delete_customer_photo_on_delete() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.delete_old_customer_photo_on_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
  old_file_path TEXT;
BEGIN
  IF OLD.avatar_url IS NOT NULL 
     AND OLD.avatar_url LIKE '%/customer-photos/%' 
     AND (NEW.avatar_url IS NULL OR NEW.avatar_url <> OLD.avatar_url) THEN
    old_file_path := split_part(OLD.avatar_url, '/customer-photos/', 2);
    IF old_file_path IS NOT NULL AND old_file_path <> '' THEN
      DELETE FROM storage.objects WHERE bucket_id = 'customer-photos' AND name = old_file_path;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.delete_old_customer_photo_on_update() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.delete_old_avatar_on_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
  old_file_path TEXT;
BEGIN
  IF OLD.avatar_url IS NOT NULL 
     AND OLD.avatar_url LIKE '%/avatars/%' 
     AND (NEW.avatar_url IS NULL OR NEW.avatar_url <> OLD.avatar_url) THEN
    old_file_path := split_part(OLD.avatar_url, '/avatars/', 2);
    IF old_file_path IS NOT NULL AND old_file_path <> '' THEN
      DELETE FROM storage.objects WHERE bucket_id = 'avatars' AND name = old_file_path;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.delete_old_avatar_on_update() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.fn_auto_create_visit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_id UUID;
BEGIN
  IF NEW.is_completed = TRUE AND (OLD.is_completed IS DISTINCT FROM TRUE) THEN
    SELECT profile_id INTO v_owner_id FROM public.customers WHERE id = NEW.customer_id;
    IF v_owner_id IS NOT NULL THEN
      INSERT INTO public.visit_logs (
        user_id,
        customer_id,
        reminder_id,
        visit_type,
        outcome,
        notes
      )
      VALUES (
        v_owner_id,
        NEW.customer_id,
        NEW.id,
        '跟進',
        '成功',
        NEW.ai_summary
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_auto_create_visit_log() FROM PUBLIC;

ALTER FUNCTION public.sync_customer_tags() SET search_path = public;
REVOKE ALL ON FUNCTION public.sync_customer_tags() FROM PUBLIC;

-- ----------------------------------------------------------------------------
-- 4. 全面清除舊 Permissive Policies (徹底防禦 OR 疊加)
-- ----------------------------------------------------------------------------

-- profiles
DROP POLICY IF EXISTS "Authenticated users can delete profiles" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated users can view profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile or admin/dev" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are readable by authenticated users" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are readable by owner or admin/dev" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are updatable by owner or admin/dev" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are insertable by owner or admin/dev" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are insertable only by admin/dev" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are deletable only by admin/dev" ON public.profiles;

-- customers
DROP POLICY IF EXISTS "Users can view their own customers" ON public.customers;
DROP POLICY IF EXISTS "Users can insert their own customers" ON public.customers;
DROP POLICY IF EXISTS "Users can update their own customers" ON public.customers;
DROP POLICY IF EXISTS "Users can delete their own customers" ON public.customers;
DROP POLICY IF EXISTS "Agents can manage own customers" ON public.customers;
DROP POLICY IF EXISTS "Admins can view team customers" ON public.customers;
DROP POLICY IF EXISTS "Admins can update team customers" ON public.customers;

-- reminders
DROP POLICY IF EXISTS "Users can view reminders for their own customers" ON public.reminders;
DROP POLICY IF EXISTS "Users can insert reminders for their own customers" ON public.reminders;
DROP POLICY IF EXISTS "Users can update reminders for their own customers" ON public.reminders;
DROP POLICY IF EXISTS "Users can delete reminders for their own customers" ON public.reminders;
DROP POLICY IF EXISTS "Agents can manage own reminders" ON public.reminders;

-- visit_logs
DROP POLICY IF EXISTS "Users can manage their own visit logs" ON public.visit_logs;
DROP POLICY IF EXISTS "Agents can manage own visit logs" ON public.visit_logs;

-- schedule_events
DROP POLICY IF EXISTS "Users can view their own schedule_events" ON public.schedule_events;
DROP POLICY IF EXISTS "Users can insert their own schedule_events" ON public.schedule_events;
DROP POLICY IF EXISTS "Users can update their own schedule_events" ON public.schedule_events;
DROP POLICY IF EXISTS "Users can delete their own schedule_events" ON public.schedule_events;
DROP POLICY IF EXISTS "Agents can manage own schedule events" ON public.schedule_events;

-- visit_projects & visit_project_customers
DROP POLICY IF EXISTS "Users can view their own visit_projects" ON public.visit_projects;
DROP POLICY IF EXISTS "Users can insert their own visit_projects" ON public.visit_projects;
DROP POLICY IF EXISTS "Users can update their own visit_projects" ON public.visit_projects;
DROP POLICY IF EXISTS "Users can delete their own visit_projects" ON public.visit_projects;
DROP POLICY IF EXISTS "Agents can manage own visit projects" ON public.visit_projects;

DROP POLICY IF EXISTS "Users can view visit_project_customers for their projects" ON public.visit_project_customers;
DROP POLICY IF EXISTS "Users can insert visit_project_customers for their projects" ON public.visit_project_customers;
DROP POLICY IF EXISTS "Users can update visit_project_customers for their projects" ON public.visit_project_customers;
DROP POLICY IF EXISTS "Users can delete visit_project_customers for their projects" ON public.visit_project_customers;
DROP POLICY IF EXISTS "Agents can manage own visit project customers" ON public.visit_project_customers;

-- customer_relationships
DROP POLICY IF EXISTS "Users can manage their own customer relationships" ON public.customer_relationships;
DROP POLICY IF EXISTS "Agents can manage own customer relationships" ON public.customer_relationships;

-- policy_clauses
DROP POLICY IF EXISTS "Allow anon insert policy_clauses" ON public.policy_clauses;
DROP POLICY IF EXISTS "Allow anon update policy_clauses" ON public.policy_clauses;
DROP POLICY IF EXISTS "Authenticated insert policy_clauses" ON public.policy_clauses;
DROP POLICY IF EXISTS "Public read policy_clauses" ON public.policy_clauses;
DROP POLICY IF EXISTS "Policy clauses readable by authenticated" ON public.policy_clauses;
DROP POLICY IF EXISTS "Policy clauses manageable by admin/dev" ON public.policy_clauses;

-- insurance_news_topics & insurance_news_articles
DROP POLICY IF EXISTS "Allow public read access for insurance_news_topics" ON public.insurance_news_topics;
DROP POLICY IF EXISTS "Allow public all access for insurance_news_topics" ON public.insurance_news_topics;
DROP POLICY IF EXISTS "News topics readable by authenticated" ON public.insurance_news_topics;
DROP POLICY IF EXISTS "News topics manageable by admin/dev" ON public.insurance_news_topics;

DROP POLICY IF EXISTS "Allow public read access for insurance_news_articles" ON public.insurance_news_articles;
DROP POLICY IF EXISTS "Allow public all access for insurance_news_articles" ON public.insurance_news_articles;
DROP POLICY IF EXISTS "News articles readable by authenticated" ON public.insurance_news_articles;
DROP POLICY IF EXISTS "News articles manageable by admin/dev" ON public.insurance_news_articles;

-- tag_categories & tags & customer_tags
DROP POLICY IF EXISTS "Allow public read access to tag_categories" ON public.tag_categories;
DROP POLICY IF EXISTS "Allow authenticated insert to tag_categories" ON public.tag_categories;
DROP POLICY IF EXISTS "Allow authenticated update to tag_categories" ON public.tag_categories;
DROP POLICY IF EXISTS "Tag categories readable by authenticated" ON public.tag_categories;
DROP POLICY IF EXISTS "Tag categories manageable by admin/dev" ON public.tag_categories;

DROP POLICY IF EXISTS "Allow public read access to tags" ON public.tags;
DROP POLICY IF EXISTS "Allow authenticated insert to tags" ON public.tags;
DROP POLICY IF EXISTS "Tags readable by authenticated" ON public.tags;
DROP POLICY IF EXISTS "Tags manageable by authenticated" ON public.tags;
DROP POLICY IF EXISTS "Tags manageable by admin/dev" ON public.tags;

DROP POLICY IF EXISTS "Users can view customer_tags for their customers" ON public.customer_tags;
DROP POLICY IF EXISTS "Users can insert customer_tags for their customers" ON public.customer_tags;
DROP POLICY IF EXISTS "Users can delete customer_tags for their customers" ON public.customer_tags;
DROP POLICY IF EXISTS "Customer tags readable and manageable by agent" ON public.customer_tags;

-- news_rss_sources
DROP POLICY IF EXISTS "Allow public read on news_rss_sources" ON public.news_rss_sources;
DROP POLICY IF EXISTS "Allow anon and auth insert on news_rss_sources" ON public.news_rss_sources;
DROP POLICY IF EXISTS "Allow anon and auth update on news_rss_sources" ON public.news_rss_sources;
DROP POLICY IF EXISTS "Allow anon and auth delete on news_rss_sources" ON public.news_rss_sources;
DROP POLICY IF EXISTS "RSS sources readable by authenticated" ON public.news_rss_sources;
DROP POLICY IF EXISTS "RSS sources manageable by admin/dev" ON public.news_rss_sources;

-- customer_policies
DROP POLICY IF EXISTS "Allow anon full access to customer_policies" ON public.customer_policies;
DROP POLICY IF EXISTS "Allow authenticated users full access to customer_policies" ON public.customer_policies;
DROP POLICY IF EXISTS "Agents can manage own customer policies" ON public.customer_policies;

-- ----------------------------------------------------------------------------
-- 5. 建立全新收斂 RLS Policies
-- ----------------------------------------------------------------------------

-- A. profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles are readable by owner or admin/dev"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (id = (select auth.uid()) OR public.is_admin_or_dev());

CREATE POLICY "Profiles are updatable by owner or admin/dev"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (id = (select auth.uid()) OR public.is_admin_or_dev())
  WITH CHECK (id = (select auth.uid()) OR public.is_admin_or_dev());

CREATE POLICY "Profiles are insertable only by admin/dev"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin_or_dev());

CREATE POLICY "Profiles are deletable only by admin/dev"
  ON public.profiles FOR DELETE
  TO authenticated
  USING (public.is_admin_or_dev());

-- B. customers
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Agents can manage own customers"
  ON public.customers FOR ALL
  TO authenticated
  USING (profile_id = (select auth.uid()) OR public.is_admin_or_dev())
  WITH CHECK (profile_id = (select auth.uid()) OR public.is_admin_or_dev());

-- C. reminders
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Agents can manage own reminders"
  ON public.reminders FOR ALL
  TO authenticated
  USING (
    customer_id IN (SELECT id FROM public.customers WHERE profile_id = (select auth.uid()))
    OR public.is_admin_or_dev()
  )
  WITH CHECK (
    customer_id IN (SELECT id FROM public.customers WHERE profile_id = (select auth.uid()))
    OR public.is_admin_or_dev()
  );

-- D. visit_logs
ALTER TABLE public.visit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Agents can manage own visit logs"
  ON public.visit_logs FOR ALL
  TO authenticated
  USING (user_id = (select auth.uid()) OR public.is_admin_or_dev())
  WITH CHECK (user_id = (select auth.uid()) OR public.is_admin_or_dev());

-- E. schedule_events
ALTER TABLE public.schedule_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Agents can manage own schedule events"
  ON public.schedule_events FOR ALL
  TO authenticated
  USING (profile_id = (select auth.uid()) OR public.is_admin_or_dev())
  WITH CHECK (profile_id = (select auth.uid()) OR public.is_admin_or_dev());

-- F. visit_projects & visit_project_customers
ALTER TABLE public.visit_projects ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Agents can manage own visit projects"
  ON public.visit_projects FOR ALL
  TO authenticated
  USING (profile_id = (select auth.uid()) OR public.is_admin_or_dev())
  WITH CHECK (profile_id = (select auth.uid()) OR public.is_admin_or_dev());

ALTER TABLE public.visit_project_customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Agents can manage own visit project customers"
  ON public.visit_project_customers FOR ALL
  TO authenticated
  USING (
    visit_project_id IN (SELECT id FROM public.visit_projects WHERE profile_id = (select auth.uid()))
    OR public.is_admin_or_dev()
  )
  WITH CHECK (
    visit_project_id IN (SELECT id FROM public.visit_projects WHERE profile_id = (select auth.uid()))
    OR public.is_admin_or_dev()
  );

-- G. customer_relationships
ALTER TABLE public.customer_relationships ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Agents can manage own customer relationships"
  ON public.customer_relationships FOR ALL
  TO authenticated
  USING (user_id = (select auth.uid()) OR public.is_admin_or_dev())
  WITH CHECK (user_id = (select auth.uid()) OR public.is_admin_or_dev());

-- H. customer_policies
ALTER TABLE public.customer_policies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Agents can manage own customer policies"
  ON public.customer_policies FOR ALL
  TO authenticated
  USING (
    customer_id IN (SELECT id FROM public.customers WHERE profile_id = (select auth.uid()))
    OR public.is_admin_or_dev()
  )
  WITH CHECK (
    customer_id IN (SELECT id FROM public.customers WHERE profile_id = (select auth.uid()))
    OR public.is_admin_or_dev()
  );

-- I. policy_clauses
ALTER TABLE public.policy_clauses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Policy clauses readable by authenticated"
  ON public.policy_clauses FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Policy clauses manageable by admin/dev"
  ON public.policy_clauses FOR ALL
  TO authenticated
  USING (public.is_admin_or_dev())
  WITH CHECK (public.is_admin_or_dev());

-- J. insurance_news_topics & insurance_news_articles
ALTER TABLE public.insurance_news_topics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "News topics readable by authenticated"
  ON public.insurance_news_topics FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "News topics manageable by admin/dev"
  ON public.insurance_news_topics FOR ALL
  TO authenticated
  USING (public.is_admin_or_dev())
  WITH CHECK (public.is_admin_or_dev());

ALTER TABLE public.insurance_news_articles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "News articles readable by authenticated"
  ON public.insurance_news_articles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "News articles manageable by admin/dev"
  ON public.insurance_news_articles FOR ALL
  TO authenticated
  USING (public.is_admin_or_dev())
  WITH CHECK (public.is_admin_or_dev());

-- K. tag_categories & tags & customer_tags (全團隊共用字典庫)
ALTER TABLE public.tag_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Tag categories readable by authenticated"
  ON public.tag_categories FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Tag categories manageable by admin/dev"
  ON public.tag_categories FOR ALL
  TO authenticated
  USING (public.is_admin_or_dev())
  WITH CHECK (public.is_admin_or_dev());

ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Tags readable by authenticated"
  ON public.tags FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Tags manageable by admin/dev"
  ON public.tags FOR ALL
  TO authenticated
  USING (public.is_admin_or_dev())
  WITH CHECK (public.is_admin_or_dev());

ALTER TABLE public.customer_tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Customer tags readable and manageable by agent"
  ON public.customer_tags FOR ALL
  TO authenticated
  USING (
    customer_id IN (SELECT id FROM public.customers WHERE profile_id = (select auth.uid()))
    OR public.is_admin_or_dev()
  )
  WITH CHECK (
    customer_id IN (SELECT id FROM public.customers WHERE profile_id = (select auth.uid()))
    OR public.is_admin_or_dev()
  );

-- L. news_rss_sources
ALTER TABLE public.news_rss_sources ENABLE ROW LEVEL SECURITY;
CREATE POLICY "RSS sources readable by authenticated"
  ON public.news_rss_sources FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "RSS sources manageable by admin/dev"
  ON public.news_rss_sources FOR ALL
  TO authenticated
  USING (public.is_admin_or_dev())
  WITH CHECK (public.is_admin_or_dev());
