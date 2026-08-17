-- Security stopgap: close public write access and prevent profile role escalation.
-- Apply after the existing 20260817 hardening migrations.

-- Reconcile legacy constraints. Two independent CHECK constraints combine with
-- AND, so the earlier schema otherwise rejects the later `deleted` status.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_profiles_role;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_status_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_profiles_status;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check CHECK (role IN ('agent', 'admin', 'dev')),
  ADD CONSTRAINT profiles_status_check CHECK (status IN ('active', 'pending', 'deleted', 'suspended'));

-- New signups are always insurance agents. Privileged roles are assigned only
-- by a trusted administrator outside the public client.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, is_google_connected, connected_providers)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'New Sales Rep'),
    'agent',
    COALESCE(NEW.raw_app_meta_data->>'provider', 'email') = 'google',
    CASE WHEN COALESCE(NEW.raw_app_meta_data->>'provider', 'email') = 'google' THEN ARRAY['google'] ELSE '{}'::text[] END
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.prevent_unprivileged_profile_security_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, auth
AS $$
BEGIN
  IF auth.uid() = NEW.id
     AND (NEW.role IS DISTINCT FROM OLD.role
       OR NEW.status IS DISTINCT FROM OLD.status
       OR NEW.team_id IS DISTINCT FROM OLD.team_id) THEN
    RAISE EXCEPTION 'Only an administrator may change account security fields';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_unprivileged_profile_security_changes ON public.profiles;
CREATE TRIGGER prevent_unprivileged_profile_security_changes
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_unprivileged_profile_security_changes();

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

-- Remove legacy permissive policies. Policies combine with OR, so merely adding
-- a restrictive policy does not neutralize an existing public policy.
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own customers" ON public.customers;
DROP POLICY IF EXISTS "Users can insert their own customers" ON public.customers;
DROP POLICY IF EXISTS "Users can update their own customers" ON public.customers;
DROP POLICY IF EXISTS "Users can delete their own customers" ON public.customers;
DROP POLICY IF EXISTS "Users can view reminders for their own customers" ON public.reminders;
DROP POLICY IF EXISTS "Users can insert reminders for their own customers" ON public.reminders;
DROP POLICY IF EXISTS "Users can update reminders for their own customers" ON public.reminders;
DROP POLICY IF EXISTS "Users can delete reminders for their own customers" ON public.reminders;
DROP POLICY IF EXISTS "Users can view their own visit_projects" ON public.visit_projects;
DROP POLICY IF EXISTS "Users can insert their own visit_projects" ON public.visit_projects;
DROP POLICY IF EXISTS "Users can update their own visit_projects" ON public.visit_projects;
DROP POLICY IF EXISTS "Users can delete their own visit_projects" ON public.visit_projects;
DROP POLICY IF EXISTS "Users can view visit_project_customers for their projects" ON public.visit_project_customers;
DROP POLICY IF EXISTS "Users can insert visit_project_customers for their projects" ON public.visit_project_customers;
DROP POLICY IF EXISTS "Users can update visit_project_customers for their projects" ON public.visit_project_customers;
DROP POLICY IF EXISTS "Users can delete visit_project_customers for their projects" ON public.visit_project_customers;
DROP POLICY IF EXISTS "Users can view their own schedule_events" ON public.schedule_events;
DROP POLICY IF EXISTS "Users can insert their own schedule_events" ON public.schedule_events;
DROP POLICY IF EXISTS "Users can update their own schedule_events" ON public.schedule_events;
DROP POLICY IF EXISTS "Users can delete their own schedule_events" ON public.schedule_events;
DROP POLICY IF EXISTS "Allow public read access to tag_categories" ON public.tag_categories;
DROP POLICY IF EXISTS "Allow authenticated insert to tag_categories" ON public.tag_categories;
DROP POLICY IF EXISTS "Allow authenticated update to tag_categories" ON public.tag_categories;
DROP POLICY IF EXISTS "Allow public read access to tags" ON public.tags;
DROP POLICY IF EXISTS "Allow authenticated insert to tags" ON public.tags;
DROP POLICY IF EXISTS "Allow public all access for insurance_news_topics" ON public.insurance_news_topics;
DROP POLICY IF EXISTS "Allow public all access for insurance_news_articles" ON public.insurance_news_articles;
DROP POLICY IF EXISTS "Allow public read on news_rss_sources" ON public.news_rss_sources;
DROP POLICY IF EXISTS "Allow anon and auth insert on news_rss_sources" ON public.news_rss_sources;
DROP POLICY IF EXISTS "Allow anon and auth update on news_rss_sources" ON public.news_rss_sources;
DROP POLICY IF EXISTS "Allow anon and auth delete on news_rss_sources" ON public.news_rss_sources;
DROP POLICY IF EXISTS "RSS sources readable by authenticated" ON public.news_rss_sources;
DROP POLICY IF EXISTS "RSS sources manageable by admin/dev" ON public.news_rss_sources;

ALTER TABLE public.news_rss_sources ENABLE ROW LEVEL SECURITY;
CREATE POLICY "RSS sources readable by authenticated"
  ON public.news_rss_sources FOR SELECT TO authenticated USING (true);
CREATE POLICY "RSS sources manageable by admin/dev"
  ON public.news_rss_sources FOR ALL TO authenticated
  USING (public.is_admin_or_dev()) WITH CHECK (public.is_admin_or_dev());

-- visit_logs uses user_id; do not reference a non-existent profile_id column.
DROP POLICY IF EXISTS "Agents can manage own visit logs" ON public.visit_logs;
CREATE POLICY "Agents can manage own visit logs"
  ON public.visit_logs FOR ALL TO authenticated
  USING (user_id = (select auth.uid()) OR public.is_admin_or_dev())
  WITH CHECK (user_id = (select auth.uid()) OR public.is_admin_or_dev());
