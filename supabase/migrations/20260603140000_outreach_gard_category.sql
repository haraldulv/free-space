-- Legg til 'gård' som gyldig outreach-kategori.
-- Kims liste (Lofoten-ringerunden) inneholder gårder, fiskerier og museer;
-- gårder får egen kategori, resten faller under 'other'.
alter table public.outreach_targets
  drop constraint if exists outreach_targets_category_check;

alter table public.outreach_targets
  add constraint outreach_targets_category_check
  check (category in ('rorbu', 'hotell', 'restaurant', 'camping', 'overnatting', 'gård', 'other'));
