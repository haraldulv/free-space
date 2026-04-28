-- Hourly pricing bands (parkering per time)
-- Lar utleier definere ulike priser for tidsbånd: f.eks. hverdager 9-17 = 50 kr/t,
-- helg 12-18 = 80 kr/t. Bånd lagres som rader i listing_pricing_rules med kind='hourly'.
--
-- Resolution-presedens for hourly bookings:
--   override (per dato) > hourly-bånd (matchende dag+time) > base hourly-pris
--
-- day_mask gjenbrukes (mandag=bit 0, søndag=bit 6).
-- start_hour/end_hour er 0..24, end-eksklusiv. For å dekke 22-06 kan utleier
-- bruke to rader: 22-24 og 0-6.
--
-- Run manually in Supabase SQL editor.

ALTER TABLE listing_pricing_rules
  ADD COLUMN IF NOT EXISTS start_hour smallint,
  ADD COLUMN IF NOT EXISTS end_hour   smallint;

-- Sjekk + oppdater kind-CHECK om den finnes (Supabase Studio viser om constrainten heter noe annet)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE constraint_name = 'listing_pricing_rules_kind_check'
  ) THEN
    EXECUTE 'ALTER TABLE listing_pricing_rules DROP CONSTRAINT listing_pricing_rules_kind_check';
  END IF;
END $$;

ALTER TABLE listing_pricing_rules
  ADD CONSTRAINT listing_pricing_rules_kind_check
  CHECK (kind IN ('weekend', 'season', 'hourly'));

-- Sanity-check: hourly-rader må ha start_hour/end_hour, andre må ha NULL
ALTER TABLE listing_pricing_rules
  ADD CONSTRAINT listing_pricing_rules_hourly_hours
  CHECK (
    (kind = 'hourly' AND start_hour IS NOT NULL AND end_hour IS NOT NULL
     AND start_hour >= 0 AND start_hour <= 23
     AND end_hour >= 1 AND end_hour <= 24
     AND end_hour > start_hour)
    OR
    (kind <> 'hourly' AND start_hour IS NULL AND end_hour IS NULL)
  );

CREATE INDEX IF NOT EXISTS idx_listing_pricing_rules_hourly
  ON listing_pricing_rules(listing_id) WHERE kind = 'hourly';

COMMENT ON COLUMN listing_pricing_rules.start_hour IS 'Hourly bånd: time 0..23 (inklusiv start). NULL for weekend/season.';
COMMENT ON COLUMN listing_pricing_rules.end_hour   IS 'Hourly bånd: time 1..24 (eksklusiv slutt). NULL for weekend/season.';
