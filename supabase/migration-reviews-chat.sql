-- =============================================
-- SpotShare: Reviews + Chat Schema
-- =============================================

-- =============================================
-- Reviews table
-- =============================================
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings(id) on delete cascade not null unique,
  listing_id text not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  rating integer not null check (rating >= 1 and rating <= 5),
  comment text not null default '',
  created_at timestamptz default now()
);

alter table public.reviews enable row level security;

create policy "Reviews are viewable by everyone"
  on public.reviews for select using (true);

create policy "Users can create reviews for their bookings"
  on public.reviews for insert with check (auth.uid() = user_id);

create policy "Users can update own reviews"
  on public.reviews for update using (auth.uid() = user_id);

create policy "Users can delete own reviews"
  on public.reviews for delete using (auth.uid() = user_id);

create index if not exists idx_reviews_listing on public.reviews(listing_id);
create index if not exists idx_reviews_user on public.reviews(user_id);

-- Auto-update listing rating and review_count
create or replace function public.update_listing_rating()
returns trigger as $$
begin
  update public.listings
  set
    rating = coalesce((select round(avg(rating)::numeric, 1)::double precision from public.reviews where listing_id = coalesce(NEW.listing_id, OLD.listing_id)), 0),
    review_count = (select count(*) from public.reviews where listing_id = coalesce(NEW.listing_id, OLD.listing_id))
  where id = coalesce(NEW.listing_id, OLD.listing_id);
  return coalesce(NEW, OLD);
end;
$$ language plpgsql security definer;

create trigger on_review_change
  after insert or update or delete on public.reviews
  for each row execute procedure public.update_listing_rating();

-- =============================================
-- Conversations table
-- =============================================
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  listing_id text not null,
  guest_id uuid references public.profiles(id) on delete cascade not null,
  host_id uuid references public.profiles(id) on delete cascade not null,
  booking_id uuid references public.bookings(id) on delete set null,
  last_message_at timestamptz default now(),
  created_at timestamptz default now(),
  unique(listing_id, guest_id)
);

alter table public.conversations enable row level security;

create policy "Users can view own conversations"
  on public.conversations for select
  using (auth.uid() = guest_id or auth.uid() = host_id);

create policy "Guests can create conversations"
  on public.conversations for insert
  with check (auth.uid() = guest_id);

create policy "Participants can update conversation"
  on public.conversations for update
  using (auth.uid() = guest_id or auth.uid() = host_id);

create index if not exists idx_conversations_guest on public.conversations(guest_id);
create index if not exists idx_conversations_host on public.conversations(host_id);

-- =============================================
-- Messages table
-- =============================================
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references public.conversations(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  read boolean not null default false,
  created_at timestamptz default now()
);

alter table public.messages enable row level security;

create policy "Participants can view messages"
  on public.messages for select
  using (
    exists (
      select 1 from public.conversations
      where id = conversation_id
      and (guest_id = auth.uid() or host_id = auth.uid())
    )
  );

create policy "Participants can send messages"
  on public.messages for insert
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.conversations
      where id = conversation_id
      and (guest_id = auth.uid() or host_id = auth.uid())
    )
  );

create policy "Participants can update messages"
  on public.messages for update
  using (
    exists (
      select 1 from public.conversations
      where id = conversation_id
      and (guest_id = auth.uid() or host_id = auth.uid())
    )
  );

create index if not exists idx_messages_conversation on public.messages(conversation_id, created_at);

-- Update conversation timestamp on new message
create or replace function public.update_conversation_timestamp()
returns trigger as $$
begin
  update public.conversations
  set last_message_at = NEW.created_at
  where id = NEW.conversation_id;
  return NEW;
end;
$$ language plpgsql security definer;

create trigger on_message_sent
  after insert on public.messages
  for each row execute procedure public.update_conversation_timestamp();

-- Enable Realtime on messages
alter publication supabase_realtime add table public.messages;
