-- Camping sesongbånd: aktiver 'season' kind med start_date/end_date + day_mask.
-- Eksisterende skjema har allerede 'season' i kind-CHECK og start_date/end_date
-- kolonner. Denne migrasjonen sikrer at day_mask kan brukes for sesong (var
-- tidligere reservert for hourly weekend-rules) og at start/end_minute er null
-- for season-rules.

-- Hvis day_mask har en NOT NULL-constraint som tvinger det for hourly,
-- relax det her (sesong kan ha day_mask = NULL = hele uken):
ALTER TABLE listing_pricing_rules
    ALTER COLUMN day_mask DROP NOT NULL;

-- Sørg for at start_minute / end_minute kan være NULL for season-rules (de er
-- relevante kun for hourly).
ALTER TABLE listing_pricing_rules
    ALTER COLUMN start_minute DROP NOT NULL,
    ALTER COLUMN end_minute DROP NOT NULL;

-- Indeks for camping-sesong-spørringer (for et gitt listing, hent alle sesong-
-- regler innenfor et datointervall).
CREATE INDEX IF NOT EXISTS idx_listing_pricing_rules_season
    ON listing_pricing_rules (listing_id, start_date, end_date)
    WHERE kind = 'season';

-- Verifisere at vi har CHECK-constraint som tillater 'season' uten time-felter:
-- (kind IN ('weekend', 'season', 'hourly') er allerede på plass — ingen endring).

-- Bekrefter at spot_id-indekset dekker både hourly og seasonal:
-- idx_listing_pricing_rules_spot_id (listing_id, spot_id) WHERE spot_id IS NOT NULL
-- — er allerede på plass, ingen endring.

-- KJØRES MANUELT i Supabase SQL Editor.
