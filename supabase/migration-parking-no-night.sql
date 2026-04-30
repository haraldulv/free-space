-- Parkering blir per-time-only. Fjern price_per_night fra både listing-nivå
-- og spot_markers JSONB for alle parkering-annonser. Camping er uberørt.
--
-- Run manually in Supabase SQL editor (eller via Supabase MCP).

-- 1. Sett price_per_night = NULL for alle parkering-listings
UPDATE listings
SET price_per_night = NULL
WHERE category = 'parking' AND price_per_night IS NOT NULL;

-- 2. Fjern pricePerNight-feltet fra hver spot i spot_markers JSONB
UPDATE listings
SET spot_markers = (
  SELECT jsonb_agg(spot - 'pricePerNight')
  FROM jsonb_array_elements(spot_markers) AS spot
)
WHERE category = 'parking'
  AND spot_markers IS NOT NULL
  AND jsonb_array_length(spot_markers) > 0
  AND EXISTS (
    SELECT 1
    FROM jsonb_array_elements(spot_markers) AS spot
    WHERE spot ? 'pricePerNight'
  );
