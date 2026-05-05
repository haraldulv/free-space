-- Min/maks antall dager per booking. nil = ingen grense.
-- Kjøres på staging-branch ved utvikling, og på prod ved promotion.

ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS min_stay_days int,
  ADD COLUMN IF NOT EXISTS max_stay_days int;
