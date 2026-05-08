-- Cached headline-pris for raskere kart/kort-rendering. Avledet fra
-- spot_markers[].pricePackages eller listing.price ved create/update.
-- Klient slipper å traversere spot_markers JSONB-arrayen for hver bobble.
ALTER TABLE listings ADD COLUMN IF NOT EXISTS display_price INT;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS display_price_suffix TEXT;
COMMENT ON COLUMN listings.display_price IS
  'Cached headline-pris (kr) for kart-bobler og listing-kort. Settes av importer/createListing/updateListing fra spot_markers[].pricePackages.';
COMMENT ON COLUMN listings.display_price_suffix IS
  'Suffix til display_price: tom for DAY (per dag), "/uke", "/mnd", "/år".';
