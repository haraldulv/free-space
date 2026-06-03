-- Tillat admin å redigere og slette kontaktlogg-oppføringer (notater).
-- Tabellen hadde fra før kun SELECT + INSERT-policies, så UPDATE/DELETE var
-- blokkert av RLS. Appen begrenser selv endring/sletting til contact_type = 'note'.
drop policy if exists "Admins update contact log" on public.outreach_contact_log;
create policy "Admins update contact log"
  on public.outreach_contact_log for update
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );

drop policy if exists "Admins delete contact log" on public.outreach_contact_log;
create policy "Admins delete contact log"
  on public.outreach_contact_log for delete
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );
