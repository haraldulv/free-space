-- 20260507_parking_type_and_price_packages
--
-- Legger til felter som trengs for å importere Hygglo + Finn parkering-annonser
-- og for å støtte den nye pris-pakke-modellen (DAY/WEEK/MONTH/YEAR).
--
-- 1. parking_type: GARAGE | OUTDOOR | PARKING_HOUSE | NULL
-- 2. rental_period_types text[]: cached liste over hvilke pakke-perioder
--    annonsen tilbyr — drives av spot_markers[].pricePackages, brukes til
--    multi-select-filteret i søk.
-- 3. source / source_id: dedupe-nøkkel for re-importer fra eksterne kilder.

ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS parking_type TEXT
    CHECK (parking_type IN ('GARAGE','OUTDOOR','PARKING_HOUSE'));
COMMENT ON COLUMN listings.parking_type IS
  'GARAGE | OUTDOOR | PARKING_HOUSE | NULL. NULL = ikke oppgitt.';

ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS rental_period_types TEXT[] DEFAULT '{}';
COMMENT ON COLUMN listings.rental_period_types IS
  'Cached unik liste av pris-pakke-perioder (DAY/WEEK/MONTH/YEAR) som annonsen tilbyr. Avledet fra spot_markers[].pricePackages.';

CREATE INDEX IF NOT EXISTS listings_rental_period_types_idx
  ON listings USING GIN (rental_period_types);

ALTER TABLE listings ADD COLUMN IF NOT EXISTS source TEXT;
COMMENT ON COLUMN listings.source IS
  'Kilde for importerte annonser (f.eks. hygglo, finn). NULL for brukerlagde annonser.';

ALTER TABLE listings ADD COLUMN IF NOT EXISTS source_id TEXT;
COMMENT ON COLUMN listings.source_id IS
  'Stabil unik id i kildens system (slug eller finnkode). Brukes med source for upsert-dedupe.';

-- Full UNIQUE constraint (ikke partial index) så ON CONFLICT (source, source_id)
-- kan brukes i upsert-baner. NULL behandles som distinct i Postgres → brukerlagde
-- annonser (begge NULL) er fortsatt OK.
ALTER TABLE listings ADD CONSTRAINT IF NOT EXISTS listings_source_source_id_unique UNIQUE (source, source_id);
