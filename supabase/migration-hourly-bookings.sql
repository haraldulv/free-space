-- Hourly bookings (parking per time)
-- Adds timestamp columns to bookings for time-precise reservations.
-- Existing bookings remain unaffected — check_in/check_out date columns continue to be the source of truth
-- for daily/nightly bookings. For hourly bookings, check_in_at/check_out_at hold the actual reservation
-- window, while check_in/check_out are set to the same day for backwards-compatible queries.
--
-- Run manually in Supabase SQL editor.

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS check_in_at  timestamptz,
  ADD COLUMN IF NOT EXISTS check_out_at timestamptz;

-- Optional index for queries that search overlapping hourly bookings.
CREATE INDEX IF NOT EXISTS idx_bookings_check_in_at  ON bookings(check_in_at)  WHERE check_in_at  IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_check_out_at ON bookings(check_out_at) WHERE check_out_at IS NOT NULL;

-- Sanity check
COMMENT ON COLUMN bookings.check_in_at  IS 'Hourly bookings only. Full timestamp of arrival. NULL for daily/nightly bookings.';
COMMENT ON COLUMN bookings.check_out_at IS 'Hourly bookings only. Full timestamp of departure. NULL for daily/nightly bookings.';
