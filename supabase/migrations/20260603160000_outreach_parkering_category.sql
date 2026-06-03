-- Legg til 'parkering' som gyldig outreach-kategori.
-- Steder merket som parkeringsplasser på Google Maps kan være aktuelle utleiere;
-- discovery henter dem nå inn som egen kategori for enklere triagering.
alter table public.outreach_targets
  drop constraint if exists outreach_targets_category_check;

alter table public.outreach_targets
  add constraint outreach_targets_category_check
  check (category in ('rorbu', 'hotell', 'restaurant', 'camping', 'overnatting', 'gård', 'parkering', 'other'));
