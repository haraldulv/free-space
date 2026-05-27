-- Add contact_person field to outreach_targets
ALTER TABLE public.outreach_targets ADD COLUMN IF NOT EXISTS contact_person text;
