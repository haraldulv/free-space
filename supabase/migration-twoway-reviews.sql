-- Fase 2B: Tovei blind reviews (Airbnb-modell)
-- Begge parter kan anmelde hverandre etter en booking. Anmeldelser holdes
-- skjult for motparten til BÅDE har levert eller 14 dager har passert.

-- 1) Utvid reviews med reviewer_role og reviewee_id
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS reviewer_role text;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS reviewee_id uuid REFERENCES profiles(id) ON DELETE CASCADE;

-- 2) Backfill: alle eksisterende reviews er gjest-reviews av host
UPDATE reviews r
SET reviewer_role = 'guest',
    reviewee_id = b.host_id
FROM bookings b
WHERE r.booking_id = b.id
  AND (r.reviewer_role IS NULL OR r.reviewee_id IS NULL);

-- 3) Sett NOT NULL og CHECK etter backfill
ALTER TABLE reviews ALTER COLUMN reviewer_role SET NOT NULL;
ALTER TABLE reviews ALTER COLUMN reviewee_id SET NOT NULL;
ALTER TABLE reviews DROP CONSTRAINT IF EXISTS reviews_reviewer_role_check;
ALTER TABLE reviews ADD CONSTRAINT reviews_reviewer_role_check
  CHECK (reviewer_role IN ('guest', 'host'));

-- 4) Bytt unique-constraint: én anmeldelse per (booking, role) i stedet for per booking
ALTER TABLE reviews DROP CONSTRAINT IF EXISTS reviews_booking_id_key;
ALTER TABLE reviews DROP CONSTRAINT IF EXISTS reviews_booking_id_role_key;
ALTER TABLE reviews ADD CONSTRAINT reviews_booking_id_role_key
  UNIQUE (booking_id, reviewer_role);

-- 5) Indeks for å hente alle reviews om en bruker (gjest- eller host-rating)
CREATE INDEX IF NOT EXISTS reviews_reviewee_idx ON reviews (reviewee_id);

-- 6) Aggregert rating på profiles (for både gjest og host)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS rating double precision NOT NULL DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS review_count integer NOT NULL DEFAULT 0;

-- 7) Oppdater listing-rating-trigger: bare gjest-reviews teller på listing
CREATE OR REPLACE FUNCTION update_listing_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE listings
  SET rating = COALESCE((
        SELECT ROUND(AVG(rating)::numeric, 1)
        FROM reviews
        WHERE listing_id = COALESCE(NEW.listing_id, OLD.listing_id)
          AND reviewer_role = 'guest'
      ), 0),
      review_count = (
        SELECT COUNT(*)
        FROM reviews
        WHERE listing_id = COALESCE(NEW.listing_id, OLD.listing_id)
          AND reviewer_role = 'guest'
      )
  WHERE id = COALESCE(NEW.listing_id, OLD.listing_id);
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- 8) Ny trigger: oppdater reviewee sin profil-rating
CREATE OR REPLACE FUNCTION update_profile_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  target_id uuid;
BEGIN
  target_id := COALESCE(NEW.reviewee_id, OLD.reviewee_id);
  IF target_id IS NOT NULL THEN
    UPDATE profiles
    SET rating = COALESCE((
          SELECT ROUND(AVG(rating)::numeric, 1)
          FROM reviews
          WHERE reviewee_id = target_id
        ), 0),
        review_count = (
          SELECT COUNT(*) FROM reviews WHERE reviewee_id = target_id
        )
    WHERE id = target_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS reviews_update_profile_rating ON reviews;
CREATE TRIGGER reviews_update_profile_rating
  AFTER INSERT OR UPDATE OR DELETE ON reviews
  FOR EACH ROW EXECUTE FUNCTION update_profile_rating();

-- 9) Re-kjør aggregeringen for eksisterende rader (backfill profil-rating)
UPDATE profiles p
SET rating = COALESCE(agg.avg_rating, 0),
    review_count = COALESCE(agg.cnt, 0)
FROM (
  SELECT reviewee_id,
         ROUND(AVG(rating)::numeric, 1) AS avg_rating,
         COUNT(*) AS cnt
  FROM reviews
  GROUP BY reviewee_id
) agg
WHERE p.id = agg.reviewee_id;
