-- ============================================================
-- Master Migration: RBAC Roles, Multi-Team, Notifications & RLS
-- Date: 2026-08-12
-- Description:
--   1. Adds `role`, `status`, `team_id`, `team_name`, `is_google_connected` to public.profiles
--   2. Creates public.notifications table with RLS policies
--   3. Updates public.customers RLS to allow team admins cross-access
-- ============================================================

-- 1. Profiles Table Expansions
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'agent' CHECK (role IN ('admin', 'dev', 'agent')),
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pending', 'suspended')),
ADD COLUMN IF NOT EXISTS team_id UUID DEFAULT 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::UUID,
ADD COLUMN IF NOT EXISTS team_name TEXT DEFAULT '國泰台北第一通訊處',
ADD COLUMN IF NOT EXISTS is_google_connected BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS connected_providers TEXT[] NOT NULL DEFAULT '{}'::TEXT[];

COMMENT ON COLUMN public.profiles.role IS 'User role: admin, dev, agent (default)';
COMMENT ON COLUMN public.profiles.status IS 'Account status: active, pending, suspended';
COMMENT ON COLUMN public.profiles.team_id IS 'Team / Organization UUID for multi-tenant isolation';

-- 2. Notifications Table Creation
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
COMMENT ON TABLE public.notifications IS 'Stores notifications for users: assignments, manager notes, AI alerts, system notices';

-- Enable RLS on notifications table
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Notifications Policies
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
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins can insert notifications') THEN
        CREATE POLICY "Admins can insert notifications"
            ON public.notifications FOR INSERT
            WITH CHECK (true);
    END IF;
END $$;

-- 3. Update Customers RLS Policy to allow admins of the same team cross-access
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins can view team customers') THEN
        CREATE POLICY "Admins can view team customers"
            ON public.customers FOR SELECT
            USING (
                auth.uid() = profile_id OR
                EXISTS (
                    SELECT 1 FROM public.profiles p
                    WHERE p.id = auth.uid() 
                      AND p.role = 'admin' 
                      AND p.team_id = (SELECT team_id FROM public.profiles WHERE id = public.customers.profile_id)
                )
            );
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins can update team customers') THEN
        CREATE POLICY "Admins can update team customers"
            ON public.customers FOR UPDATE
            USING (
                auth.uid() = profile_id OR
                EXISTS (
                    SELECT 1 FROM public.profiles p
                    WHERE p.id = auth.uid() 
                      AND p.role = 'admin'
                )
            );
    END IF;
END $$;
