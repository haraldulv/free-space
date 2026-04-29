-- Per-plass tilgjengelighets-bånd og pris-overstyring.
-- spot_id NULL = listing-wide (eksisterende rader, backward-compat).
-- spot_id satt = gjelder kun denne plassen (matcher SpotMarker.id i listings.spot_markers jsonb).
--
-- Server-overlap-sjekk filtrerer rules WHERE spot_id IN (NULL, target_spot_id):
-- spot-spesifikke regler overstyrer listing-wide.
--
-- Run manually in Supabase SQL editor.

ALTER TABLE listing_pricing_rules
  ADD COLUMN IF NOT EXISTS spot_id text;

ALTER TABLE listing_pricing_overrides
  ADD COLUMN IF NOT EXISTS spot_id text;

CREATE INDEX IF NOT EXISTS idx_listing_pricing_rules_spot_id
  ON listing_pricing_rules (listing_id, spot_id) WHERE spot_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_listing_pricing_overrides_spot_id
  ON listing_pricing_overrides (listing_id, spot_id) WHERE spot_id IS NOT NULL;

COMMENT ON COLUMN listing_pricing_rules.spot_id IS
  'Hvilken plass (SpotMarker.id) regelen gjelder. NULL = listing-wide.';
COMMENT ON COLUMN listing_pricing_overrides.spot_id IS
  'Hvilken plass (SpotMarker.id) overstyringen gjelder. NULL = listing-wide.';
