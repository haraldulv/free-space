-- Booking time snapshot + MAX_INSTANT_NIGHTS (max-dager-regel)
-- Kjøres manuelt i Supabase SQL editor av Harald.
--
-- Bakgrunn: bookinger brukte listingens live-verdier for check_in_time/check_out_time.
-- Hvis host endrer tider etter en booking er opprettet, ble eksisterende bookinger
-- retroaktivt påvirket (A hadde avtalt utsjekk 11:00, men kunne plutselig se 09:00).
--
-- Løsningen er å snapshotte tidspunktene på bookingen ved opprettelse. Nye bookinger
-- (fra commit [denne commiten] og utover) vil populere disse kolonnene automatisk.
-- Gamle bookinger får NULL og faller tilbake til listing.check_in_time i UI.

alter table bookings
  add column if not exists check_in_time text,
  add column if not exists check_out_time text;

-- Sanity: vis at kolonnene er lagt til
select column_name, data_type
from information_schema.columns
where table_name = 'bookings' and column_name in ('check_in_time', 'check_out_time');
