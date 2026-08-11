-- ============================================================
-- Migration: Add role and third-party connection fields to profiles
-- Date: 2026-08-12
-- Description:
--   1. Adds `role` ('admin', 'dev', 'agent') column to public.profiles
--   2. Adds `is_google_connected` and `connected_providers` columns
--   3. Updates trigger function `handle_new_user()`
-- ============================================================

-- 1. Add role column with CHECK constraint and default value 'agent'
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'agent' CHECK (role IN ('admin', 'dev', 'agent'));

-- 2. Add third-party account connection tracking columns
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_google_connected BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS connected_providers TEXT[] NOT NULL DEFAULT '{}'::TEXT[];

-- 3. Add column comment documentation
COMMENT ON COLUMN public.profiles.role IS 'User role for Role-Based Access Control: admin, dev, agent (default)';
COMMENT ON COLUMN public.profiles.is_google_connected IS 'Indicates whether the user has authorized Google account connection';
COMMENT ON COLUMN public.profiles.connected_providers IS 'List of connected third-party OAuth providers (e.g. google)';

-- 4. Update trigger to populate default role & initial connected providers on auth user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    initial_provider TEXT;
    is_google BOOLEAN := FALSE;
    providers_list TEXT[] := '{}';
BEGIN
    -- Extract OAuth provider if available
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
        is_google_connected, 
        connected_providers
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'New Sales Rep'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'agent'),
        is_google,
        providers_list
    )
    ON CONFLICT (id) DO UPDATE SET
        role = EXCLUDED.role,
        is_google_connected = EXCLUDED.is_google_connected,
        connected_providers = EXCLUDED.connected_providers;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
