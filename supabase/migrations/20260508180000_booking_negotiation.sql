-- Forhandling-flyt for "Forespørsel"-annonser:
-- Gjest sender forespørsel uten Stripe → host og gjest motforhandler ubegrenset
-- → en av dem godtar siste tilbud → PaymentIntent opprettes → gjest betaler innen 24t.
-- Modellen er en-til-mange booking_offers per booking, med chronologisk historikk.

-- 1) booking_offers: hver pris/dato-kombinasjon i forhandlingen.
create table if not exists public.booking_offers (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings(id) on delete cascade not null,
  proposed_by uuid references public.profiles(id) on delete set null not null,
  proposed_by_role text not null check (proposed_by_role in ('guest', 'host')),
  total_price integer not null,
  price_breakdown jsonb,
  check_in date not null,
  check_out date not null,
  selected_extras jsonb,
  selected_spot_ids text[],
  message text,
  status text not null default 'pending'
    check (status in ('pending', 'superseded', 'accepted', 'declined', 'expired')),
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_booking_offers_booking_status
  on public.booking_offers (booking_id, status);
create index if not exists idx_booking_offers_booking_created
  on public.booking_offers (booking_id, created_at desc);

alter table public.booking_offers enable row level security;

-- Booking-deltakere ser tilbud. Admins ser alt.
drop policy if exists "Booking participants can view offers" on public.booking_offers;
create policy "Booking participants can view offers"
  on public.booking_offers for select
  using (
    exists (
      select 1 from public.bookings b
      where b.id = booking_id
      and (b.user_id = auth.uid() or b.host_id = auth.uid())
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.is_admin = true
    )
  );

-- INSERT/UPDATE kun via service role (API verifiserer rolle + state).
-- Ingen klient-policies for INSERT/UPDATE/DELETE.

-- 2) bookings: utvidet status + forhandling-state-kolonner.
alter table public.bookings drop constraint if exists bookings_status_check;
alter table public.bookings add constraint bookings_status_check
  check (status in (
    'pending', 'requested', 'confirmed', 'cancelled',
    'awaiting_host', 'awaiting_guest', 'awaiting_payment', 'expired', 'declined'
  ));

alter table public.bookings
  add column if not exists current_offer_id uuid references public.booking_offers(id) on delete set null;

alter table public.bookings
  add column if not exists negotiation_round smallint not null default 0;

alter table public.bookings
  add column if not exists awaiting_party text
    check (awaiting_party in ('host', 'guest'));

alter table public.bookings
  add column if not exists payment_deadline timestamptz;

create index if not exists idx_bookings_awaiting_party
  on public.bookings (awaiting_party, status)
  where awaiting_party is not null;

create index if not exists idx_bookings_payment_deadline
  on public.bookings (payment_deadline)
  where status = 'awaiting_payment';

-- 3) messages: kind + metadata for offer-bobler i chat.
alter table public.messages
  add column if not exists kind text not null default 'text'
    check (kind in ('text', 'offer', 'offer_accepted', 'offer_declined', 'system'));

alter table public.messages
  add column if not exists metadata jsonb;

-- Backfill (ingen rader i staging, men idempotent).
update public.messages set kind = 'text' where kind is null;
