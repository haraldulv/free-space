-- Migrasjon TU-58: gjør stille transfer-feil synlige.
-- Når `process-payouts`-cron eller `transfer.failed`-webhook oppdager at en
-- Stripe-transfer feilet, lagrer vi Stripe-feilmeldingen + tidspunkt så vert
-- og admin kan finne ut hva som er galt. Tidligere ble feilen kun logget til
-- konsoll og raden ble stående med transfer_status='pending' for alltid.
--
-- Applied to staging 2026-05-13. Promotion til prod skjer ved staging→main-merge.

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS transfer_error TEXT;

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS transfer_failed_at TIMESTAMPTZ;
