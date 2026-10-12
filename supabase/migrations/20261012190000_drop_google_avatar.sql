-- Dropp Google-avatar ved signup (2026-10-12)
--
-- Google OAuth legger auto-genererte monogram-avatarer (bokstav på tilfeldig
-- farget bakgrunn) i raw_user_meta_data->>'avatar_url'. De skal ikke inn i
-- Tuno: nye brukere starter med tom avatar (klientene viser Tuno-initialer)
-- til de laster opp eget bilde i appen/innstillinger. Signup-nødbryteren
-- (app_settings.signups_enabled) beholdes uendret.
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
    ''
  );
  return new;
end;
$$;
revoke execute on function public.handle_new_user() from anon, authenticated, public;

-- Datavask: fjern eksisterende Google-avatarer (profiler + denormalisert
-- kopi på annonser). Egne opplastinger (avatars-bucketen) beholdes.
update public.profiles
  set avatar_url = ''
  where avatar_url like '%googleusercontent.com%';

update public.listings
  set host_avatar = ''
  where host_avatar like '%googleusercontent.com%';
