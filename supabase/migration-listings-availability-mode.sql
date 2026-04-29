-- Availability mode: 'always' (24/7 ledig) eller 'bands' (kun innenfor hourly-bånd)
-- Når mode='bands' skal serveren avvise hourly bookings utenfor matchende bånd.
-- Backward-compat: 524+ seedede listings får 'always' (default), bookinger fungerer uendret.
--
-- Run manually in Supabase SQL editor.

ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS availability_mode text DEFAULT 'always';

-- Drop existing constraint if it exists (for idempotent re-run)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE constraint_name = 'listings_availability_mode_check'
  ) THEN
    EXECUTE 'ALTER TABLE listings DROP CONSTRAINT listings_availability_mode_check';
  END IF;
END $$;

ALTER TABLE listings
  ADD CONSTRAINT listings_availability_mode_check
  CHECK (availability_mode IN ('always', 'bands'));

COMMENT ON COLUMN listings.availability_mode IS
  'always = plassen er ledig 24/7 (booking-API faller tilbake til base-pris). bands = kun ledig innenfor hourly-bånd; bookinger utenfor avvises 409.';
