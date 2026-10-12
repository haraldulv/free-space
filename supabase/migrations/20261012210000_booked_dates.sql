-- Multi-velg datoer (parkering): leietaker kan booke ikke-sammenhengende
-- enkeltdager i én booking. check_in/check_out beholdes som konvolutt
-- (første/siste dag); booked_dates er autoritativ dagliste når satt.
-- null = sammenhengende periode (inklusiv begge endepunkter for parkering,
-- eksklusiv utsjekksdag for camping). Nye parkering-bookinger skriver alltid
-- booked_dates. booking_offers trenger kolonnen fordi accept kopierer
-- offer -> booking.

alter table public.bookings
  add column if not exists booked_dates jsonb;

alter table public.booking_offers
  add column if not exists booked_dates jsonb;
