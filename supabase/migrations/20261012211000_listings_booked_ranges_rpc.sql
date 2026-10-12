-- Tilgjengelighets-RPC for kalendere. bookings har kun SELECT-policyer for
-- egne bookinger (user_id) og vertens (host_id), så gjesters kalendere kunne
-- aldri se andres bookinger: opptatte dager så ledige ut helt til betalingen
-- ble avvist av create-ruten. Denne security definer-funksjonen eksponerer
-- KUN anonyme opptatt-data (datoer + plass-id-er), ingen bruker-id, pris
-- eller status. Pending-bookinger regnes som døde etter 30 min (samme TTL
-- som create-ruten). NB: bookings.listing_id er text, ikke uuid.

create or replace function public.listings_booked_ranges(p_listing_ids text[])
returns table (
  listing_id text,
  check_in date,
  check_out date,
  booked_dates jsonb,
  selected_spot_ids text[]
)
language sql
security definer
set search_path = public
stable
as $$
  select b.listing_id, b.check_in, b.check_out, b.booked_dates, b.selected_spot_ids
  from public.bookings b
  where b.listing_id = any(p_listing_ids)
    and b.status in ('confirmed', 'pending', 'requested')
    and b.check_out >= current_date
    and (b.status <> 'pending' or b.created_at > now() - interval '30 minutes');
$$;

revoke all on function public.listings_booked_ranges(text[]) from public;
grant execute on function public.listings_booked_ranges(text[]) to anon, authenticated;
