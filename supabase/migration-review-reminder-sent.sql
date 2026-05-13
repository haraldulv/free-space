-- Migrasjon TU-62: aktiverer review-reminder-cron.
-- Cron-jobben i `app/api/cron/review-reminders/route.ts` filtrerer på
-- review_reminder_sent IS NOT TRUE og setter flagget når email + push er
-- sendt. Uten kolonnen feiler cronen umiddelbart.
--
-- Applied to staging 2026-05-13. Promotion til prod skjer ved staging→main-merge.

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS review_reminder_sent BOOLEAN DEFAULT FALSE;

-- Partial index for å gjøre cron-spørringa rask når tabellen vokser.
-- Filter speiler nøyaktig hva cronen filtrerer på.
CREATE INDEX IF NOT EXISTS idx_bookings_review_reminder_pending
  ON bookings (check_out)
  WHERE review_reminder_sent IS NOT TRUE AND status = 'confirmed';
