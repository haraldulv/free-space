-- Lagre utleier-valgt farge på hourly pricing-bånd. Default NULL → kalender
-- velger farge fra rule.id-hash. Verdi 0-4 mapper til palett.

ALTER TABLE listing_pricing_rules
  ADD COLUMN IF NOT EXISTS color_index smallint;

COMMENT ON COLUMN listing_pricing_rules.color_index IS 'Hourly bånd: utleier-valgt farge-indeks (0-4 i palett). NULL = derives fra rule.id-hash.';
