-- Utleier-outreach: arbeidsflate for admin-rekruttering av nye hosts.
-- Discovery via Google Places (rorbuer/hoteller/restauranter i Lofoten),
-- status + notater per target, e-post-utsending via Resend, kontakt-logg.
--
-- Alle tre tabeller er kun lese-/skrivbare av admins (is_admin = true).

-- 1) outreach_targets: én rad per potensiell utleier-aktør.
create table if not exists public.outreach_targets (
  id uuid primary key default gen_random_uuid(),
  place_id text unique not null,
  name text not null,
  category text not null
    check (category in ('rorbu', 'hotell', 'restaurant', 'camping', 'overnatting', 'other')),
  area text not null default 'lofoten',
  address text,
  phone text,
  website text,
  email text,
  lat numeric,
  lng numeric,
  rating numeric,
  user_ratings_total integer,
  status text not null default 'not_contacted'
    check (status in ('not_contacted', 'queued', 'contacted', 'follow_up', 'responded', 'declined', 'onboarded')),
  notes text,
  last_contacted_at timestamptz,
  last_contacted_by uuid references public.profiles(id) on delete set null,
  follow_up_at timestamptz,
  raw_places_json jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists outreach_targets_status_idx on public.outreach_targets (status);
create index if not exists outreach_targets_area_category_idx on public.outreach_targets (area, category);
create index if not exists outreach_targets_follow_up_idx on public.outreach_targets (follow_up_at) where follow_up_at is not null;

alter table public.outreach_targets enable row level security;

drop policy if exists "Admins read outreach targets" on public.outreach_targets;
create policy "Admins read outreach targets"
  on public.outreach_targets for select
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );

drop policy if exists "Admins insert outreach targets" on public.outreach_targets;
create policy "Admins insert outreach targets"
  on public.outreach_targets for insert
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );

drop policy if exists "Admins update outreach targets" on public.outreach_targets;
create policy "Admins update outreach targets"
  on public.outreach_targets for update
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );

drop policy if exists "Admins delete outreach targets" on public.outreach_targets;
create policy "Admins delete outreach targets"
  on public.outreach_targets for delete
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );

-- Trigger: oppdater updated_at automatisk.
create or replace function public.outreach_targets_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists outreach_targets_set_updated_at on public.outreach_targets;
create trigger outreach_targets_set_updated_at
before update on public.outreach_targets
for each row execute function public.outreach_targets_set_updated_at();

-- 2) outreach_contact_log: append-only logg over hver kontakt-handling.
create table if not exists public.outreach_contact_log (
  id uuid primary key default gen_random_uuid(),
  target_id uuid not null references public.outreach_targets(id) on delete cascade,
  contacted_by uuid references public.profiles(id) on delete set null,
  contact_type text not null check (contact_type in ('email', 'phone', 'note')),
  recipient text,
  subject text,
  body text,
  status_after text,
  created_at timestamptz not null default now()
);

create index if not exists outreach_contact_log_target_idx
  on public.outreach_contact_log (target_id, created_at desc);

alter table public.outreach_contact_log enable row level security;

drop policy if exists "Admins read contact log" on public.outreach_contact_log;
create policy "Admins read contact log"
  on public.outreach_contact_log for select
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );

drop policy if exists "Admins insert contact log" on public.outreach_contact_log;
create policy "Admins insert contact log"
  on public.outreach_contact_log for insert
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );

-- 3) outreach_email_templates: redigerbare mailmaler.
create table if not exists public.outreach_email_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  subject text not null,
  body text not null,
  is_default boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Bare én default-mal av gangen.
create unique index if not exists outreach_email_templates_one_default
  on public.outreach_email_templates ((1)) where is_default = true;

alter table public.outreach_email_templates enable row level security;

drop policy if exists "Admins read templates" on public.outreach_email_templates;
create policy "Admins read templates"
  on public.outreach_email_templates for select
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );

drop policy if exists "Admins write templates" on public.outreach_email_templates;
create policy "Admins write templates"
  on public.outreach_email_templates for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );

create or replace function public.outreach_email_templates_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists outreach_email_templates_set_updated_at on public.outreach_email_templates;
create trigger outreach_email_templates_set_updated_at
before update on public.outreach_email_templates
for each row execute function public.outreach_email_templates_set_updated_at();

-- 4) Seed default-mal. Variabler: {name}, {tuno_link}, {app_store_link}.
insert into public.outreach_email_templates (name, subject, body, is_default)
select
  'Standard utleier-pitch',
  'Tjen penger på plassen din med Tuno',
  $template$Hei {name},

Vi i Tuno har laget en plattform der private og profesjonelle utleiere kan leie ut parkering og bobil-/campingplasser direkte til reisende — på samme måte som Airbnb gjør for boliger.

Vi ser at Lofoten har enormt mye bobil- og campervan-trafikk hver sommer, og vi tror du kunne tjent godt på å åpne plassen din for besøkende.

Hva du får:
• Tjen penger på plass du allerede har, uten å rote med Facebook-DM-er eller kontant
• Du bestemmer selv pris, regler og tilgjengelighet
• Daglig utbetaling rett til din konto
• Vi tar oss av kortbetaling, kontrakt og kommunikasjon

Det er gratis å opprette en annonse — vi tjener kun en liten provisjon når noen booker.

Sjekk ut tuno.no: {tuno_link}
Last ned appen: {app_store_link}

Spørsmål? Bare svar på denne mailen.

Vennlig hilsen,
Harald
Tuno
$template$,
  true
where not exists (select 1 from public.outreach_email_templates);
