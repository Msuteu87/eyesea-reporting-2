-- Migration: Schema Expansion for Seafarers, Vessels, and Events

-- 1. Core Role Expansion
-- Ensure user_role type exists
do $$ begin
    create type user_role as enum ('volunteer', 'ambassador', 'admin');
exception
    when duplicate_object then null;
end $$;

-- Add 'seafarer' to user_role enum if not exists
do $$ begin
    alter type user_role add value 'seafarer';
exception
    when duplicate_object then null;
    when others then null;
end $$;

-- Ensure profiles table exists
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade not null primary key
);

-- Ensure 'role' column exists in profiles
do $$ begin
    if not exists (select 1 from information_schema.columns where table_name = 'profiles' and column_name = 'role') then
        alter table public.profiles add column role user_role default 'volunteer'::user_role;
    end if;
end $$;


-- 2. Organization & Vessel Management

-- Update Organizations to support types
do $$ begin
    alter table public.organizations add column org_type text check (org_type in ('shipping_company', 'ship_management', 'ngo', 'other'));
exception
    when duplicate_column then null;
    when others then null;
end $$;

-- New: Vessels Table
create table if not exists public.vessels (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    imo_number text unique, -- 7 digits
    mmsi text, -- Maritime Mobile Service Identity (9 digits)
    flag_state text, -- Country of registration
    org_id uuid references public.organizations(id) on delete set null, -- Manager/Owner
    created_at timestamptz default now()
);

-- Seafarer Assignment (Dynamic)
-- Track current vessel in profiles
do $$ begin
    alter table public.profiles add column current_vessel_id uuid references public.vessels(id);
exception
    when duplicate_column then null;
end $$;

-- 3. Ambassadors & Regions

-- Add region fields to profiles (for Ambassadors)
do $$ begin
    alter table public.profiles add column ambassador_region_country text;
exception
    when duplicate_column then null;
end $$;

do $$ begin
    alter table public.profiles add column ambassador_region_name text;
exception
    when duplicate_column then null;
end $$;

-- 4. Events & Cleanups

-- New: Events Table
create table if not exists public.events (
    id uuid default gen_random_uuid() primary key,
    organizer_id uuid references public.profiles(id) not null,
    title text not null,
    description text,
    location geography(POINT) not null,
    address text,
    start_time timestamptz not null,
    end_time timestamptz,
    status text default 'planned' check (status in ('planned', 'active', 'completed', 'cancelled')),
    created_at timestamptz default now()
);

-- New: Event Participants Table
create table if not exists public.event_participants (
    event_id uuid references public.events(id) on delete cascade,
    user_id uuid references public.profiles(id) on delete cascade,
    status text default 'joined' check (status in ('joined', 'checked_in', 'cancelled')),
    joined_at timestamptz default now(),
    primary key (event_id, user_id)
);

-- 5. Report Tagging
-- Link reports to vessels and events
do $$ begin
    alter table public.reports add column vessel_id uuid references public.vessels(id);
exception
    when duplicate_column then null;
end $$;

do $$ begin
    alter table public.reports add column event_id uuid references public.events(id);
exception
    when duplicate_column then null;
end $$;

-- 6. RLS Policies

-- Vessels
alter table public.vessels enable row level security;
drop policy if exists "Vessels are viewable by everyone." on public.vessels;
create policy "Vessels are viewable by everyone." on public.vessels for select using (true);

-- Events
alter table public.events enable row level security;
drop policy if exists "Events are viewable by everyone." on public.events;
create policy "Events are viewable by everyone." on public.events for select using (true);

drop policy if exists "Ambassadors can create events." on public.events;
create policy "Ambassadors can create events." on public.events for insert with check (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'ambassador'::user_role)
);

drop policy if exists "Ambassadors can update own events." on public.events;
create policy "Ambassadors can update own events." on public.events for update using (
    organizer_id = auth.uid()
);

-- Event Participants
alter table public.event_participants enable row level security;
drop policy if exists "Participants viewable by everyone." on public.event_participants;
create policy "Participants viewable by everyone." on public.event_participants for select using (true);

drop policy if exists "Authenticated users can join events." on public.event_participants;
create policy "Authenticated users can join events." on public.event_participants for insert with check (auth.uid() = user_id);

drop policy if exists "Users can update their participation status." on public.event_participants;
create policy "Users can update their participation status." on public.event_participants for update using (auth.uid() = user_id);
