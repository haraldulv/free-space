-- =============================================
-- Free Space: Database Schema
-- =============================================

-- Profiles table (extends Supabase auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  response_rate integer default 0,
  response_time text default 'innen 1 time',
  joined_year integer default extract(year from now()),
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Public profiles are viewable by everyone"
  on public.profiles for select using (true);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert with check (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Listings table
create table if not exists public.listings (
  id text primary key,
  host_id uuid references public.profiles(id) on delete set null,
  title text not null,
  description text not null,
  category text not null check (category in ('parking', 'camping')),
  images text[] not null default '{}',
  city text not null,
  region text not null,
  address text not null,
  lat double precision not null,
  lng double precision not null,
  price integer not null,
  price_unit text not null check (price_unit in ('time', 'natt')),
  rating double precision not null default 0,
  review_count integer not null default 0,
  amenities text[] not null default '{}',
  max_vehicle_length integer,
  spots integer not null default 1,
  tags text[] not null default '{}',
  -- Host info (denormalized for mock data without real user accounts)
  host_name text,
  host_avatar text,
  host_response_rate integer,
  host_response_time text,
  host_joined_year integer,
  host_listings_count integer,
  created_at timestamptz default now()
);

alter table public.listings enable row level security;

create policy "Listings are viewable by everyone"
  on public.listings for select using (true);

create policy "Authenticated users can create listings"
  on public.listings for insert with check (auth.role() = 'authenticated');

create policy "Users can update own listings"
  on public.listings for update using (auth.uid() = host_id);

create policy "Users can delete own listings"
  on public.listings for delete using (auth.uid() = host_id);

-- Bookings table
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  listing_id text references public.listings(id) on delete cascade not null,
  check_in date not null,
  check_out date not null,
  total_price integer not null,
  status text not null default 'confirmed' check (status in ('confirmed', 'cancelled')),
  created_at timestamptz default now()
);

alter table public.bookings enable row level security;

create policy "Users can view own bookings"
  on public.bookings for select using (auth.uid() = user_id);

create policy "Users can create bookings"
  on public.bookings for insert with check (auth.uid() = user_id);

create policy "Users can update own bookings"
  on public.bookings for update using (auth.uid() = user_id);

-- Favorites table
create table if not exists public.favorites (
  user_id uuid references public.profiles(id) on delete cascade,
  listing_id text references public.listings(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, listing_id)
);

alter table public.favorites enable row level security;

create policy "Users can view own favorites"
  on public.favorites for select using (auth.uid() = user_id);

create policy "Users can add favorites"
  on public.favorites for insert with check (auth.uid() = user_id);

create policy "Users can remove favorites"
  on public.favorites for delete using (auth.uid() = user_id);

-- Indexes
create index if not exists idx_listings_category on public.listings(category);
create index if not exists idx_listings_city on public.listings(city);
create index if not exists idx_listings_region on public.listings(region);
create index if not exists idx_listings_lat_lng on public.listings(lat, lng);
create index if not exists idx_bookings_user on public.bookings(user_id);
create index if not exists idx_favorites_user on public.favorites(user_id);
