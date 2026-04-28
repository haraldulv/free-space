-- listings.price_unit CHECK-constraint utvidet med 'hour' så parkering
-- per time kan opprettes uten å feile på insert.
--
-- Anvendt i prod 2026-04-28 via MCP. Gammel constraint tillot bare
-- 'time' (camping-historisk navn for døgn) og 'natt' — derfor feilet
-- iOS-side annonse-opprettelse med "violates check constraint
-- listings_price_unit_check" når priceUnit var 'hour'.
ALTER TABLE public.listings DROP CONSTRAINT IF EXISTS listings_price_unit_check;
ALTER TABLE public.listings ADD CONSTRAINT listings_price_unit_check
  CHECK (price_unit = ANY (ARRAY['time'::text, 'natt'::text, 'hour'::text]));
