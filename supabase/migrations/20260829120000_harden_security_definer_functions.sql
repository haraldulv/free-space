-- Hardening fra Supabase security advisors (2026-08-29):
-- 1) Trigger-funksjonene under er SECURITY DEFINER og var kallbare via
--    /rest/v1/rpc/<fn> for anon + authenticated. Appen kaller ingen av dem
--    via rpc(), så vi revokerer EXECUTE fra API-rollene. Triggere kjører
--    fortsatt fint (de eies av postgres).
-- 2) Låser search_path på funksjonene (function_search_path_mutable).

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'handle_new_user',
    'rls_auto_enable',
    'sync_listings_host_denorm',
    'update_conversation_timestamp',
    'update_listing_rating',
    'update_profile_rating',
    'outreach_targets_set_updated_at',
    'outreach_email_templates_set_updated_at'
  ] loop
    if exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = fn and p.pronargs = 0
    ) then
      execute format('revoke execute on function public.%I() from anon, authenticated, public', fn);
      execute format('alter function public.%I() set search_path = public', fn);
    end if;
  end loop;
end $$;
