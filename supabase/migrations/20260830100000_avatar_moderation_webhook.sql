-- Profilbilde-sjekk uavhengig av klient (2026-08-30)
-- Gamle app-versjoner kaller ikke /api/moderate-avatar. Trigger på
-- profiles.avatar_url sørger for at serveren sjekker bildet uansett.

create or replace function public.avatar_moderation_webhook()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_url text;
  secret text;
begin
  if new.avatar_url is null or new.avatar_url = '' or new.avatar_url is not distinct from old.avatar_url then
    return new;
  end if;
  -- Kun våre egne storage-URL-er (OAuth-avatarer fra Google/Apple hoppes over)
  if position('/storage/v1/object/public/avatars/' in new.avatar_url) = 0 then
    return new;
  end if;
  select decrypted_secret into base_url from vault.decrypted_secrets where name = 'moderation_webhook_base_url' limit 1;
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'moderation_webhook_secret' limit 1;
  if base_url is null or secret is null then
    return new;
  end if;
  begin
    perform net.http_post(
      url := base_url || '/api/moderation/avatar',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || secret),
      body := jsonb_build_object('userId', new.id::text, 'avatarUrl', new.avatar_url),
      timeout_milliseconds := 30000
    );
  exception when others then
    raise warning 'avatar_moderation_webhook failed: %', sqlerrm;
  end;
  return new;
end;
$$;
revoke execute on function public.avatar_moderation_webhook() from anon, authenticated, public;

drop trigger if exists profiles_avatar_moderation_webhook on public.profiles;
create trigger profiles_avatar_moderation_webhook
  after update of avatar_url on public.profiles
  for each row execute function public.avatar_moderation_webhook();
