-- Add 'interested' to outreach status CHECK constraint
ALTER TABLE public.outreach_targets DROP CONSTRAINT IF EXISTS outreach_targets_status_check;
ALTER TABLE public.outreach_targets ADD CONSTRAINT outreach_targets_status_check
  CHECK (status IN ('not_contacted','queued','contacted','no_response','follow_up','responded','interested','declined','onboarded'));
