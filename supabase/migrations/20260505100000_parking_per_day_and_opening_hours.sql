-- Parkering: per-time → per-dag, ny opening_hours-kolonne.
-- Alle eksisterende annonser er testdata og slettes.

-- 1. Slett alle eksisterende test-data (cascade fra listings)
DELETE FROM public.listings;

-- 2. Defensivt: slett hourly-bånd fra pricing-rules om noen skulle ligge igjen
DELETE FROM public.listing_pricing_rules WHERE kind = 'hourly';

-- 3. Drop availability_mode (var koblet til hourly-bånd)
ALTER TABLE public.listings DROP CONSTRAINT IF EXISTS listings_availability_mode_check;
ALTER TABLE public.listings DROP COLUMN IF EXISTS availability_mode;

-- 4. Drop price_per_hour-kolonne (per-time-prising er fjernet)
ALTER TABLE public.listings DROP COLUMN IF EXISTS price_per_hour;

-- 5. Reduser price_unit-CHECK fra ['time','natt','hour'] til ['time','natt']
ALTER TABLE public.listings DROP CONSTRAINT IF EXISTS listings_price_unit_check;
ALTER TABLE public.listings ADD CONSTRAINT listings_price_unit_check
  CHECK (price_unit IN ('time', 'natt'));

-- 6. Ny kolonne for åpningstid på listings (per-listing default).
--    NULL = døgnåpent. Ellers JSONB { "mon": "09:00-17:00", "sat": null, ... }
--    Per-spot override lagres i listings.spot_markers[].openingHours (jsonb-array, ingen schema-endring)
ALTER TABLE public.listings
  ADD COLUMN IF NOT EXISTS opening_hours jsonb DEFAULT NULL;
