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
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

COMMENT ON TABLE public.profiles IS 'Stores basic salesperson profile metadata, linked to Supabase Auth users.';

-- -------------------------------------------------------------
-- 2. Customers Table (Sales Reps' Clients)
-- -------------------------------------------------------------
CREATE TABLE public.customers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
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
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'New Sales Rep')
    );
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
