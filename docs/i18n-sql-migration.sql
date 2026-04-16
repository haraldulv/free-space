-- i18n Fase 1: Legg til preferred_language på profiles
-- Kjør dette manuelt i Supabase SQL editor før deploy av LocaleSwitcher-persistens

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS preferred_language text DEFAULT 'nb';

-- Valgfritt: sjekk-constraint slik at kun støttede locales kan lagres
ALTER TABLE profiles
  DROP CONSTRAINT IF EXISTS profiles_preferred_language_check;
ALTER TABLE profiles
  ADD CONSTRAINT profiles_preferred_language_check
  CHECK (preferred_language IN ('nb', 'en', 'de'));

-- Kommentar til kolonnen
COMMENT ON COLUMN profiles.preferred_language IS 'Brukerens foretrukne språk (nb, en, de). Lagres av LocaleSwitcher.';
