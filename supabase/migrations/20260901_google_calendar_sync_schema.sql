-- Migration: 20260901_google_calendar_sync_schema.sql
-- Description: Add sync_status column to schedule_events table for Google Calendar bidirectional sync support

ALTER TABLE public.schedule_events 
ADD COLUMN IF NOT EXISTS sync_status TEXT DEFAULT 'local_only';

-- Ensure index exists for Google Calendar event lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_schedule_events_google_sync 
    ON public.schedule_events(profile_id, google_calendar_id, google_event_id);
