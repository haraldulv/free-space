-- Admin-varsel ved nye brukere (2026-10-17)
-- Trigger på profiles-insert (opprettes av handle_new_user ved signup,
-- både web og app) som kaller /api/webhooks/new-user via pg_net. Gjenbruker
-- vault-secretene fra moderering-webhooken (base_url + secret).

create or replace function public.new_user_webhook()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_url text;
  secret text;
  v_email text;
begin
  select decrypted_secret into base_url from vault.decrypted_secrets where name = 'moderation_webhook_base_url' limit 1;
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'moderation_webhook_secret' limit 1;
  if base_url is null or secret is null then
    return new;
  end if;
  select email into v_email from auth.users where id = new.id;
  begin
    perform net.http_post(
      url := base_url || '/api/webhooks/new-user',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || secret),
      body := jsonb_build_object('userId', new.id::text, 'email', v_email, 'fullName', new.full_name),
      timeout_milliseconds := 30000
    );
  exception when others then
    raise warning 'new_user_webhook failed: %', sqlerrm;
  end;
  return new;
end;
$$;
revoke execute on function public.new_user_webhook() from anon, authenticated, public;

drop trigger if exists profiles_new_user_webhook on public.profiles;
create trigger profiles_new_user_webhook
  after insert on public.profiles
  for each row execute function public.new_user_webhook();
