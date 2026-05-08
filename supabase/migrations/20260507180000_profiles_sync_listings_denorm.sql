-- Auto-sync denormalisert host_avatar/host_name på listings når profil oppdateres.
-- Sparer klienten for ekstra fetchHostStats-call og holder DB-state konsistent.
-- Oppdager både avatar_url og full_name-endringer.
CREATE OR REPLACE FUNCTION sync_listings_host_denorm()
RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.avatar_url IS DISTINCT FROM OLD.avatar_url)
     OR (NEW.full_name IS DISTINCT FROM OLD.full_name) THEN
    UPDATE listings
    SET
      host_avatar = NEW.avatar_url,
      host_name = NEW.full_name
    WHERE host_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS profiles_sync_listings_denorm ON profiles;
CREATE TRIGGER profiles_sync_listings_denorm
  AFTER UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_listings_host_denorm();
