-- ==============================================================================
-- Migration: Add custom_attributes to customers table for Round-Trip Fidelity
-- Date: 2026-08-22
-- ==============================================================================

ALTER TABLE public.customers 
ADD COLUMN IF NOT EXISTS custom_attributes JSONB DEFAULT '{}'::jsonb NOT NULL;

-- Create GIN index for high-speed dynamic attribute querying
CREATE INDEX IF NOT EXISTS idx_customers_custom_attributes ON public.customers USING GIN (custom_attributes);

COMMENT ON COLUMN public.customers.custom_attributes IS 'Dynamic custom attributes (Key-Value) for round-trip import/export fidelity';
