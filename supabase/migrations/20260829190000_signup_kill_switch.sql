-- Nødbryter for registrering (2026-08-29)
--
-- app_settings er en liten key/value-tabell (kun admin/service kan endre,
-- alle kan lese). `signups_enabled=false` gjør at handle_new_user-triggeren
-- avbryter INSERT i auth.users, dvs. registrering feiler på Supabase-nivå
-- uansett klient (web, iOS, direkte API). Vaktbikkja slår av automatisk ved
-- unormal signup-hastighet; admin slår på igjen i /admin/moderering.
-- Klientene leser flagget først og viser en pen melding.

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);
alter table public.app_settings enable row level security;

drop policy if exists "Anyone can read app settings" on public.app_settings;
create policy "Anyone can read app settings" on public.app_settings for select using (true);

drop policy if exists "Admins can update app settings" on public.app_settings;
create policy "Admins can update app settings" on public.app_settings for update to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin));

insert into public.app_settings (key, value) values
  ('signups_enabled', 'true'::jsonb),
  ('signups_disabled_reason', '""'::jsonb),
  ('last_sweep_at', 'null'::jsonb)
on conflict (key) do nothing;

-- Samme kropp som før + guard. (Eksisterende: insert into profiles fra
-- raw_user_meta_data.)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce((select value = 'false'::jsonb from public.app_settings where key = 'signups_enabled'), false) then
    raise exception 'Registrering er midlertidig stengt. Prøv igjen senere.' using errcode = 'P0001';
  end if;

  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$;
revoke execute on function public.handle_new_user() from anon, authenticated, public;
