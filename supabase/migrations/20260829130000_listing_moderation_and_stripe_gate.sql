-- Stålporter for annonser (2026-08-29):
--
--  1) moderation_status på listings. Nye annonser starter som 'pending' og
--     er USYNLIGE for publikum til de er 'approved' (AI-sjekk via
--     /api/moderation/listing, evt. admin manuelt).
--  2) host_stripe_ready denormalisert fra profiles.stripe_onboarding_complete.
--     Annonser vises kun når hostens Stripe-konto er verifisert.
--  3) RLS SELECT-policy håndhever begge deler i databasen, siden både web
--     og iOS leser/skriver listings direkte via PostgREST.
--  4) BEFORE-trigger hindrer at host selv setter moderation_status/
--     host_stripe_ready, og re-køer moderering når bilder/tekst endres.
--  5) pg_net-webhook kaller moderasjons-API-et ved ny/endret annonse.
--     URL + secret ligger i Vault (per miljø, settes utenfor migrasjonen):
--       select vault.create_secret('https://www.tuno.no', 'moderation_webhook_base_url');
--       select vault.create_secret('<hemmelig>', 'moderation_webhook_secret');
--  6) notifications.type utvidet med moderasjons-typer.

-- ---------------------------------------------------------------------
-- 1 + 2) Kolonner
-- ---------------------------------------------------------------------
alter table public.listings
  add column if not exists moderation_status text not null default 'pending',
  add column if not exists moderation_reason text,
  add column if not exists moderation_ai jsonb,
  add column if not exists moderated_at timestamptz,
  add column if not exists moderated_by uuid references public.profiles(id) on delete set null,
  add column if not exists host_stripe_ready boolean not null default false;

alter table public.listings drop constraint if exists listings_moderation_status_check;
alter table public.listings add constraint listings_moderation_status_check
  check (moderation_status in ('pending', 'approved', 'flagged', 'rejected'));

create index if not exists listings_moderation_status_idx on public.listings (moderation_status);

-- Backfill: eksisterende annonser beholdes synlige (grandfathered) og får
-- host_stripe_ready fra profilen.
update public.listings l
   set host_stripe_ready = coalesce(p.stripe_onboarding_complete, false)
  from public.profiles p
 where p.id = l.host_id;

update public.listings
   set moderation_status = 'approved', moderated_at = now()
 where moderation_status = 'pending';

-- ---------------------------------------------------------------------
-- 2) profiles.stripe_onboarding_complete -> listings.host_stripe_ready
-- ---------------------------------------------------------------------
create or replace function public.sync_listings_host_stripe_ready()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.stripe_onboarding_complete is distinct from old.stripe_onboarding_complete then
    update public.listings
       set host_stripe_ready = coalesce(new.stripe_onboarding_complete, false)
     where host_id = new.id;
  end if;
  return new;
end;
$$;
revoke execute on function public.sync_listings_host_stripe_ready() from anon, authenticated, public;

drop trigger if exists profiles_sync_listings_stripe_ready on public.profiles;
create trigger profiles_sync_listings_stripe_ready
  after update on public.profiles
  for each row execute function public.sync_listings_host_stripe_ready();

-- ---------------------------------------------------------------------
-- 4) Host kan ikke manipulere moderasjonsfelter; endringer re-køes
-- ---------------------------------------------------------------------
create or replace function public.listings_enforce_moderation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  -- service_role (server/webhook/admin-actions) og direkte postgres-sesjoner
  -- (SQL editor, migrasjoner) er privilegerte. Vanlige brukere via PostgREST
  -- har auth.role() = 'authenticated'/'anon'.
  privileged boolean := coalesce(auth.role(), 'postgres') in ('service_role', 'postgres');
begin
  new.host_stripe_ready := coalesce(
    (select stripe_onboarding_complete from public.profiles where id = new.host_id),
    false
  );

  if not privileged then
    if tg_op = 'INSERT' then
      new.moderation_status := 'pending';
      new.moderation_reason := null;
      new.moderation_ai := null;
      new.moderated_at := null;
      new.moderated_by := null;
    else
      new.moderation_status := old.moderation_status;
      new.moderation_reason := old.moderation_reason;
      new.moderation_ai := old.moderation_ai;
      new.moderated_at := old.moderated_at;
      new.moderated_by := old.moderated_by;

      -- Nye bilder eller ny tekst = ny vurdering. Avviste annonser forblir
      -- avvist til admin sier noe annet.
      if old.moderation_status <> 'rejected' and (
           new.images is distinct from old.images
        or new.title is distinct from old.title
        or new.description is distinct from old.description
      ) then
        new.moderation_status := 'pending';
        new.moderation_reason := null;
        new.moderation_ai := null;
        new.moderated_at := null;
        new.moderated_by := null;
      end if;
    end if;
  end if;

  return new;
end;
$$;
revoke execute on function public.listings_enforce_moderation() from anon, authenticated, public;

drop trigger if exists listings_enforce_moderation on public.listings;
create trigger listings_enforce_moderation
  before insert or update on public.listings
  for each row execute function public.listings_enforce_moderation();

-- ---------------------------------------------------------------------
-- 3) RLS: publikum ser kun godkjente annonser fra Stripe-verifiserte hosts
-- ---------------------------------------------------------------------
-- Hjelper (security definer) så policyen kan sjekke bookings/conversations
-- uten å trigge deres RLS. Gjester/verter skal fortsatt kunne åpne en
-- annonse de har booking eller samtale på, selv om den senere ble skjult.
create or replace function public.can_view_listing(p_listing_id text, p_host_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is not null and (
      auth.uid() = p_host_id
      or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
      or exists (select 1 from public.bookings b where b.listing_id = p_listing_id and (b.user_id = auth.uid() or b.host_id = auth.uid()))
      or exists (select 1 from public.conversations c where c.listing_id = p_listing_id and (c.guest_id = auth.uid() or c.host_id = auth.uid()))
    );
$$;
revoke execute on function public.can_view_listing(text, uuid) from public;
grant execute on function public.can_view_listing(text, uuid) to anon, authenticated;

drop policy if exists "Listings are viewable by everyone" on public.listings;
drop policy if exists "Public can view approved listings" on public.listings;
create policy "Public can view approved listings"
  on public.listings for select
  using (
    (moderation_status = 'approved' and host_stripe_ready and is_active is distinct from false)
    or public.can_view_listing(id, host_id)
  );

-- ---------------------------------------------------------------------
-- 5) Webhook til moderasjons-API-et via pg_net
-- ---------------------------------------------------------------------
create extension if not exists pg_net with schema extensions;

create or replace function public.listings_moderation_webhook()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_url text;
  secret text;
begin
  if new.moderation_status <> 'pending' then
    return new;
  end if;

  select decrypted_secret into base_url from vault.decrypted_secrets where name = 'moderation_webhook_base_url' limit 1;
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'moderation_webhook_secret' limit 1;

  if base_url is null or secret is null then
    raise warning 'listings_moderation_webhook: vault secrets missing, cron sweep will pick up listing %', new.id;
    return new;
  end if;

  begin
    perform net.http_post(
      url := base_url || '/api/moderation/listing',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || secret
      ),
      body := jsonb_build_object('listingId', new.id)
    );
  exception when others then
    raise warning 'listings_moderation_webhook failed for %: %', new.id, sqlerrm;
  end;

  return new;
end;
$$;
revoke execute on function public.listings_moderation_webhook() from anon, authenticated, public;

drop trigger if exists listings_moderation_webhook on public.listings;
create trigger listings_moderation_webhook
  after insert or update of moderation_status, images, title, description on public.listings
  for each row execute function public.listings_moderation_webhook();

-- ---------------------------------------------------------------------
-- 6) notifications.type
-- ---------------------------------------------------------------------
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in (
    'booking_received', 'booking_confirmed', 'booking_cancelled', 'new_message',
    'new_review', 'payout_sent',
    'listing_approved', 'listing_rejected', 'listing_pending', 'admin_moderation'
  ));
