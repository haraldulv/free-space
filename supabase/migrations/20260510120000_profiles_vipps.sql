-- Vipps Login (Fase 1): link Vipps-identifier (sub) til profiles.
-- vipps_sub er primær identifier ved gjeninnlogging fordi e-post i Vipps
-- kan endres uten at sub gjør det.
alter table public.profiles
  add column if not exists vipps_sub text,
  add column if not exists vipps_phone text;

-- Unique constraint så samme Vipps-bruker ikke kan kobles til flere profiler.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_vipps_sub_unique'
  ) then
    alter table public.profiles
      add constraint profiles_vipps_sub_unique unique (vipps_sub);
  end if;
end $$;

create index if not exists profiles_vipps_sub_idx on public.profiles(vipps_sub);
