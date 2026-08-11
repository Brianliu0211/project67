-- Enable pg_cron and pg_net extensions in Supabase Postgres
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Schedule daily midnight (02:00 AM Taiwan Time / 18:00 UTC) automatic call to crawl-insurance-products Edge Function
SELECT cron.schedule(
  'daily-insurance-crawler-job',
  '0 18 * * *',
  $$
  SELECT net.http_post(
    url := 'https://algufuoxkeizxwkofmmp.supabase.co/functions/v1/crawl-insurance-products',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer sb_publishable_hEIRyFKMgmbB2qVOVioGBQ_61oJxceL"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
