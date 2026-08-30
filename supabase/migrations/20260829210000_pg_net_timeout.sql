-- pg_net har 5 s standard-timeout; moderasjons-API-et bruker 8–15 s (Claude).
-- Sett 30 s på begge webhook-kallene. (Svaret brukes ikke, men timeout
-- avbryter ellers forbindelsen før serveren er ferdig.)

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
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || secret),
      body := jsonb_build_object('listingId', new.id),
      timeout_milliseconds := 30000
    );
  exception when others then
    raise warning 'listings_moderation_webhook failed for %: %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

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
      body := payload,
      timeout_milliseconds := 30000
    );
  exception when others then
    raise warning 'content_moderation_webhook failed: %', sqlerrm;
  end;
  return new;
end;
$$;
