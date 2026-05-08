-- Support-chat: utvider conversations + messages med type='support'.
-- Bruker eksisterende realtime-, RLS-, og UI-stack uendret for type='booking'.

-- 1) Conversations: type-kolonne, nullable refs, admin-assignment.
alter table public.conversations
  add column if not exists type text not null default 'booking'
  check (type in ('booking', 'support'));

alter table public.conversations alter column listing_id drop not null;
alter table public.conversations alter column host_id drop not null;

alter table public.conversations
  add column if not exists assigned_admin_id uuid references public.profiles(id) on delete set null;

-- 2) Bytt unique-constraint til partial-indekser per type.
alter table public.conversations drop constraint if exists conversations_listing_id_guest_id_key;

create unique index if not exists conversations_booking_unique
  on public.conversations (listing_id, guest_id)
  where type = 'booking';

create unique index if not exists conversations_support_unique
  on public.conversations (guest_id)
  where type = 'support';

-- 3) RLS: utvid eksisterende policies til å la admins se og delta i support-samtaler.
drop policy if exists "Users can view own conversations" on public.conversations;
create policy "Users can view own conversations"
  on public.conversations for select
  using (
    auth.uid() = guest_id
    or auth.uid() = host_id
    or (
      type = 'support'
      and exists (
        select 1 from public.profiles
        where profiles.id = auth.uid() and profiles.is_admin = true
      )
    )
  );

drop policy if exists "Guests can create conversations" on public.conversations;
create policy "Guests can create conversations"
  on public.conversations for insert
  with check (auth.uid() = guest_id);

drop policy if exists "Participants can update conversation" on public.conversations;
create policy "Participants can update conversation"
  on public.conversations for update
  using (
    auth.uid() = guest_id
    or auth.uid() = host_id
    or (
      type = 'support'
      and exists (
        select 1 from public.profiles
        where profiles.id = auth.uid() and profiles.is_admin = true
      )
    )
  );

-- 4) Messages: utvid policies på samme måte.
drop policy if exists "Participants can view messages" on public.messages;
create policy "Participants can view messages"
  on public.messages for select
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
      and (
        c.guest_id = auth.uid()
        or c.host_id = auth.uid()
        or (
          c.type = 'support'
          and exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.is_admin = true
          )
        )
      )
    )
  );

drop policy if exists "Participants can send messages" on public.messages;
create policy "Participants can send messages"
  on public.messages for insert
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id
      and (
        c.guest_id = auth.uid()
        or c.host_id = auth.uid()
        or (
          c.type = 'support'
          and exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.is_admin = true
          )
        )
      )
    )
  );

drop policy if exists "Participants can update messages" on public.messages;
create policy "Participants can update messages"
  on public.messages for update
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
      and (
        c.guest_id = auth.uid()
        or c.host_id = auth.uid()
        or (
          c.type = 'support'
          and exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.is_admin = true
          )
        )
      )
    )
  );
