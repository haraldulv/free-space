-- Dual-pricing: en parkering kan tilbys både per time OG per døgn samtidig.
-- listings.price + price_unit beholdes som "primær" (det som vises i søk).
-- price_per_hour og price_per_night er begge nullable; minst én må være satt.
--
-- Backfill kopierer eksisterende price til riktig kolonne basert på price_unit.
--
-- Run manually in Supabase SQL editor.

ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS price_per_hour int,
  ADD COLUMN IF NOT EXISTS price_per_night int;

-- Backfill for eksisterende rader
UPDATE listings SET
  price_per_hour = CASE WHEN price_unit = 'hour' THEN price ELSE price_per_hour END,
  price_per_night = CASE WHEN price_unit IN ('time', 'natt') THEN price ELSE price_per_night END
WHERE price_per_hour IS NULL OR price_per_night IS NULL;

COMMENT ON COLUMN listings.price_per_hour IS
  'Pris per time i kr (parkering). NULL = denne pris-modusen ikke tilbudt.';
COMMENT ON COLUMN listings.price_per_night IS
  'Pris per døgn (24t) eller natt i kr. NULL = denne pris-modusen ikke tilbudt.';
