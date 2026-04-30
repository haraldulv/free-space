-- Halvtime-presisjon på hourly pricing-bånd
-- Lar utleier sette tilgjengelighet/pris-bånd som starter/slutter på XX:30.
-- Bookinger ligger fortsatt på hele timer; bånd kan være finere.
--
-- Run manually in Supabase SQL editor.

ALTER TABLE listing_pricing_rules
  ADD COLUMN IF NOT EXISTS start_minute smallint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS end_minute   smallint NOT NULL DEFAULT 0;

-- Drop gammel hourly-hours-constraint (ny versjon må også validere minutt-felter)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE constraint_name = 'listing_pricing_rules_hourly_hours'
  ) THEN
    EXECUTE 'ALTER TABLE listing_pricing_rules DROP CONSTRAINT listing_pricing_rules_hourly_hours';
  END IF;
END $$;

ALTER TABLE listing_pricing_rules
  ADD CONSTRAINT listing_pricing_rules_hourly_hours
  CHECK (
    (kind = 'hourly'
     AND start_hour IS NOT NULL AND end_hour IS NOT NULL
     AND start_hour >= 0 AND start_hour <= 23
     AND end_hour >= 1 AND end_hour <= 24
     AND start_minute IN (0, 30)
     AND end_minute IN (0, 30)
     AND (start_hour * 60 + start_minute) < (end_hour * 60 + end_minute))
    OR
    (kind <> 'hourly'
     AND start_hour IS NULL AND end_hour IS NULL
     AND start_minute = 0 AND end_minute = 0)
  );

COMMENT ON COLUMN listing_pricing_rules.start_minute IS 'Hourly bånd: minutt 0 eller 30. Default 0.';
COMMENT ON COLUMN listing_pricing_rules.end_minute   IS 'Hourly bånd: minutt 0 eller 30. Default 0.';
