-- Migrate status from text to text[] array (multi-tag support)
ALTER TABLE outreach_targets ADD COLUMN IF NOT EXISTS statuses text[] NOT NULL DEFAULT '{not_contacted}';
UPDATE outreach_targets SET statuses = ARRAY[status] WHERE status IS NOT NULL;
ALTER TABLE outreach_targets DROP CONSTRAINT IF EXISTS outreach_targets_status_check;
ALTER TABLE outreach_targets DROP COLUMN IF EXISTS status;
DROP INDEX IF EXISTS outreach_targets_status_idx;
CREATE INDEX IF NOT EXISTS outreach_targets_statuses_idx ON outreach_targets USING GIN (statuses);
