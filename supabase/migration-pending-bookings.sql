-- Fase 2A: Non-instant booking-godkjenning
-- Lar utleier godkjenne/avvise bookinger på annonser med instant_booking=false.
-- Penger autoriseres ved booking, captures først ved godkjenning.

-- 1) Utvid status-enum: tillat 'pending' (venter på Stripe-betaling) og
--    'requested' (Stripe har autorisert, venter på host-godkjenning).
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE bookings ADD CONSTRAINT bookings_status_check
  CHECK (status IN ('pending', 'requested', 'confirmed', 'cancelled'));

-- 2) Felter for godkjenningsflyten.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS approval_deadline timestamptz;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS host_responded_at timestamptz;

-- 3) Indeks for cron som finner utløpte forespørsler.
CREATE INDEX IF NOT EXISTS bookings_requested_deadline_idx
  ON bookings (approval_deadline)
  WHERE status = 'requested';
