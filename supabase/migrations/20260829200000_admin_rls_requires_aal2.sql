-- Admin-rettigheter i RLS krever tofaktor (AAL2) (2026-08-29)
--
-- Alle policyer som ga tilgang via `profiles.is_admin = true` går nå via
-- public.is_admin_aal2(): is_admin OG JWT-claim aal = 'aal2'. Admin er kun
-- Harald på web (/admin krever MFA i middleware), så dette lukker døra for
-- en stjålet admin-sesjon uten kode. Service-role påvirkes ikke.
-- NB: iOS-appen har ingen MFA-flyt, så admin-privilegier (support-chat,
-- rapporter) er ikke tilgjengelige fra appen. Vanlig bruk er upåvirket.

create or replace function public.is_admin_aal2()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
     and coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
     and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true);
$$;
revoke execute on function public.is_admin_aal2() from public;
grant execute on function public.is_admin_aal2() to anon, authenticated;

-- can_view_listing: admin-grenen krever AAL2
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
      or public.is_admin_aal2()
      or exists (select 1 from public.bookings b where b.listing_id = p_listing_id and (b.user_id = auth.uid() or b.host_id = auth.uid()))
      or exists (select 1 from public.conversations c where c.listing_id = p_listing_id and (c.guest_id = auth.uid() or c.host_id = auth.uid()))
    );
$$;

-- conversations
drop policy if exists "Participants can update conversation" on public.conversations;
create policy "Participants can update conversation" on public.conversations for update
  using (auth.uid() = guest_id or auth.uid() = host_id or (type = 'support' and public.is_admin_aal2()));
drop policy if exists "Users can view own conversations" on public.conversations;
create policy "Users can view own conversations" on public.conversations for select
  using (auth.uid() = guest_id or auth.uid() = host_id or (type = 'support' and public.is_admin_aal2()));

-- messages
drop policy if exists "Participants can send messages" on public.messages;
create policy "Participants can send messages" on public.messages for insert
  with check (auth.uid() = sender_id and exists (
    select 1 from public.conversations c
     where c.id = messages.conversation_id
       and (c.guest_id = auth.uid() or c.host_id = auth.uid() or (c.type = 'support' and public.is_admin_aal2()))));
drop policy if exists "Participants can update messages" on public.messages;
create policy "Participants can update messages" on public.messages for update
  using (exists (
    select 1 from public.conversations c
     where c.id = messages.conversation_id
       and (c.guest_id = auth.uid() or c.host_id = auth.uid() or (c.type = 'support' and public.is_admin_aal2()))));
drop policy if exists "Participants can view messages" on public.messages;
create policy "Participants can view messages" on public.messages for select
  using (exists (
    select 1 from public.conversations c
     where c.id = messages.conversation_id
       and (c.guest_id = auth.uid() or c.host_id = auth.uid() or (c.type = 'support' and public.is_admin_aal2()))));

-- booking_offers
drop policy if exists "Booking participants can view offers" on public.booking_offers;
create policy "Booking participants can view offers" on public.booking_offers for select
  using (exists (select 1 from public.bookings b where b.id = booking_offers.booking_id and (b.user_id = auth.uid() or b.host_id = auth.uid()))
         or public.is_admin_aal2());

-- outreach
drop policy if exists "Admins delete outreach targets" on public.outreach_targets;
create policy "Admins delete outreach targets" on public.outreach_targets for delete using (public.is_admin_aal2());
drop policy if exists "Admins insert outreach targets" on public.outreach_targets;
create policy "Admins insert outreach targets" on public.outreach_targets for insert with check (public.is_admin_aal2());
drop policy if exists "Admins read outreach targets" on public.outreach_targets;
create policy "Admins read outreach targets" on public.outreach_targets for select using (public.is_admin_aal2());
drop policy if exists "Admins update outreach targets" on public.outreach_targets;
create policy "Admins update outreach targets" on public.outreach_targets for update using (public.is_admin_aal2());

drop policy if exists "Admins delete contact log" on public.outreach_contact_log;
create policy "Admins delete contact log" on public.outreach_contact_log for delete using (public.is_admin_aal2());
drop policy if exists "Admins insert contact log" on public.outreach_contact_log;
create policy "Admins insert contact log" on public.outreach_contact_log for insert with check (public.is_admin_aal2());
drop policy if exists "Admins read contact log" on public.outreach_contact_log;
create policy "Admins read contact log" on public.outreach_contact_log for select using (public.is_admin_aal2());
drop policy if exists "Admins update contact log" on public.outreach_contact_log;
create policy "Admins update contact log" on public.outreach_contact_log for update using (public.is_admin_aal2()) with check (public.is_admin_aal2());

drop policy if exists "Admins read templates" on public.outreach_email_templates;
create policy "Admins read templates" on public.outreach_email_templates for select using (public.is_admin_aal2());
drop policy if exists "Admins write templates" on public.outreach_email_templates;
create policy "Admins write templates" on public.outreach_email_templates for all using (public.is_admin_aal2()) with check (public.is_admin_aal2());

-- reports / content_flags / app_settings
drop policy if exists "Admins can update reports" on public.reports;
create policy "Admins can update reports" on public.reports for update to authenticated using (public.is_admin_aal2());
drop policy if exists "Users can view own reports" on public.reports;
create policy "Users can view own reports" on public.reports for select to authenticated
  using (reporter_id = auth.uid() or public.is_admin_aal2());
drop policy if exists "Admins manage content flags" on public.content_flags;
create policy "Admins manage content flags" on public.content_flags for all to authenticated
  using (public.is_admin_aal2()) with check (public.is_admin_aal2());
drop policy if exists "Admins can update app settings" on public.app_settings;
create policy "Admins can update app settings" on public.app_settings for update to authenticated using (public.is_admin_aal2());
