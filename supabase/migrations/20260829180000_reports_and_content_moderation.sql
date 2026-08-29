-- Rapporter + innholdsmoderering (2026-08-29)
--
--  1) reports: brukere kan rapportere annonse / bruker / samtale / anmeldelse.
--  2) content_flags: asynkron AI-vurdering av meldinger og anmeldelser.
--     Innholdet leveres umiddelbart; flagg gir admin-varsel (fail open på
--     tekst, i motsetning til annonser som er fail closed).
--  3) pg_net-webhook på messages/reviews INSERT → /api/moderation/text.
--  4) notifications.type utvidet.

-- ---------------------------------------------------------------------
-- 1) reports
-- ---------------------------------------------------------------------
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  target_type text not null check (target_type in ('listing', 'user', 'conversation', 'review')),
  target_id text not null,
  reason text not null check (reason in ('scam', 'inappropriate', 'harassment', 'fake', 'spam', 'other')),
  details text,
  status text not null default 'open' check (status in ('open', 'reviewed', 'dismissed')),
  admin_note text,
  handled_by uuid references public.profiles(id) on delete set null,
  handled_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists reports_status_idx on public.reports (status, created_at desc);
create index if not exists reports_target_idx on public.reports (target_type, target_id);

alter table public.reports enable row level security;

drop policy if exists "Users can create reports" on public.reports;
create policy "Users can create reports"
  on public.reports for insert to authenticated
  with check (reporter_id = auth.uid());

drop policy if exists "Users can view own reports" on public.reports;
create policy "Users can view own reports"
  on public.reports for select to authenticated
  using (reporter_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin));

drop policy if exists "Admins can update reports" on public.reports;
create policy "Admins can update reports"
  on public.reports for update to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin));

-- Enkel spam-brems: maks 20 rapporter per bruker per døgn.
create or replace function public.reports_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from public.reports where reporter_id = new.reporter_id and created_at > now() - interval '1 day') >= 20 then
    raise exception 'For mange rapporter. Prøv igjen i morgen.';
  end if;
  return new;
end;
$$;
revoke execute on function public.reports_rate_limit() from anon, authenticated, public;
drop trigger if exists reports_rate_limit on public.reports;
create trigger reports_rate_limit before insert on public.reports
  for each row execute function public.reports_rate_limit();

-- ---------------------------------------------------------------------
-- 2) content_flags
-- ---------------------------------------------------------------------
create table if not exists public.content_flags (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('message', 'review', 'avatar')),
  content_id text not null,
  author_id uuid references public.profiles(id) on delete cascade,
  severity text not null check (severity in ('low', 'medium', 'high')),
  category text not null,
  reason text,
  excerpt text,
  ai jsonb,
  status text not null default 'open' check (status in ('open', 'reviewed', 'dismissed')),
  handled_by uuid references public.profiles(id) on delete set null,
  handled_at timestamptz,
  created_at timestamptz not null default now(),
  unique (content_type, content_id)
);
create index if not exists content_flags_status_idx on public.content_flags (status, created_at desc);

alter table public.content_flags enable row level security;
drop policy if exists "Admins manage content flags" on public.content_flags;
create policy "Admins manage content flags"
  on public.content_flags for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin));

-- ---------------------------------------------------------------------
-- 3) Webhook: nye meldinger/anmeldelser → /api/moderation/text
-- ---------------------------------------------------------------------
create or replace function public.content_moderation_webhook()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_url text;
  secret text;
  payload jsonb;
begin
  select decrypted_secret into base_url from vault.decrypted_secrets where name = 'moderation_webhook_base_url' limit 1;
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'moderation_webhook_secret' limit 1;
  if base_url is null or secret is null then
    return new;
  end if;

  if tg_table_name = 'messages' then
    -- Kun vanlige tekstmeldinger (ikke system/tilbud)
    if coalesce(new.kind, 'text') <> 'text' or new.content is null or length(trim(new.content)) < 2 then
      return new;
    end if;
    payload := jsonb_build_object('type', 'message', 'id', new.id::text);
  else
    if new.comment is null or length(trim(new.comment)) < 2 then
      return new;
    end if;
    payload := jsonb_build_object('type', 'review', 'id', new.id::text);
  end if;

  begin
    perform net.http_post(
      url := base_url || '/api/moderation/text',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || secret),
      body := payload
    );
  exception when others then
    raise warning 'content_moderation_webhook failed: %', sqlerrm;
  end;
  return new;
end;
$$;
revoke execute on function public.content_moderation_webhook() from anon, authenticated, public;

drop trigger if exists messages_moderation_webhook on public.messages;
create trigger messages_moderation_webhook after insert on public.messages
  for each row execute function public.content_moderation_webhook();

drop trigger if exists reviews_moderation_webhook on public.reviews;
create trigger reviews_moderation_webhook after insert on public.reviews
  for each row execute function public.content_moderation_webhook();

-- ---------------------------------------------------------------------
-- 4) notifications.type
-- ---------------------------------------------------------------------
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in (
    'booking_received', 'booking_confirmed', 'booking_cancelled', 'new_message',
    'new_review', 'payout_sent',
    'listing_approved', 'listing_rejected', 'listing_pending', 'admin_moderation',
    'admin_report', 'admin_content_flag'
  ));
