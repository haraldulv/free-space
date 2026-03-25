-- Add is_active column to listings (default true for existing listings)
ALTER TABLE listings ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

-- Add availability/blocked dates for calendar management
-- blocked_dates stores an array of date strings ["2026-03-28", "2026-03-29", ...]
ALTER TABLE listings ADD COLUMN IF NOT EXISTS blocked_dates jsonb DEFAULT '[]'::jsonb;

-- Update search to only return active listings (update RLS or queries)
-- No RLS change needed - we filter in application code
