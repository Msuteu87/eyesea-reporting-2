-- Enable PostGIS
create extension if not exists postgis;

-- Create Schema

-- PROFILES
do $$ begin
    create type user_role as enum ('volunteer', 'ambassador', 'admin');
exception
    when duplicate_object then null;
end $$;

create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade not null primary key,
  display_name text,
  avatar_url text,
  country text,
  city text,
  role user_role default 'volunteer'::user_role,
  is_anonymous_default boolean default false,
  reports_count int default 0,
  streak_days int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ORGANIZATIONS
create table if not exists public.organizations (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  slug text unique not null,
  logo_url text,
  country text,
  description text,
  website text,
  verified boolean default false,
  created_at timestamptz default now()
);

-- ORGANIZATION MEMBERS
do $$ begin
    create type org_role as enum ('member', 'moderator', 'owner');
exception
    when duplicate_object then null;
end $$;

create table if not exists public.organization_members (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  org_id uuid references public.organizations(id) on delete cascade not null,
  role org_role default 'member'::org_role,
  joined_at timestamptz default now(),
  unique(user_id, org_id)
);

-- REPORTS
do $$ begin
    create type pollution_type as enum ('plastic', 'oil', 'debris', 'sewage', 'fishing_gear', 'other');
exception
    when duplicate_object then null;
end $$;

do $$ begin
    create type report_status as enum ('pending', 'verified', 'resolved', 'rejected');
exception
    when duplicate_object then null;
end $$;


create table if not exists public.reports (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete set null,
  org_id uuid references public.organizations(id) on delete set null,
  location geography(POINT),
  address text,
  pollution_type pollution_type not null,
  severity int check (severity >= 1 and severity <= 5),
  status report_status default 'pending'::report_status,
  notes text,
  is_anonymous boolean default false,
  reported_at timestamptz default now(),
  verified_at timestamptz,
  resolved_at timestamptz
);

-- REPORT IMAGES
create table if not exists public.report_images (
  id uuid default gen_random_uuid() primary key,
  report_id uuid references public.reports(id) on delete cascade not null,
  storage_path text not null,
  is_primary boolean default false,
  created_at timestamptz default now()
);

-- AI ANALYSIS
create table if not exists public.ai_analysis (
  id uuid default gen_random_uuid() primary key,
  report_id uuid references public.reports(id) on delete cascade not null unique,
  gemini_response jsonb,
  pollution_detected text[],
  confidence float,
  description text,
  analyzed_at timestamptz default now()
);

-- BADGES
create table if not exists public.badges (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  icon text,
  description text
);

-- USER BADGES
create table if not exists public.user_badges (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  badge_id uuid references public.badges(id) on delete cascade not null,
  earned_at timestamptz default now(),
  unique(user_id, badge_id)
);

-- FUNCTIONS & TRIGGERS

-- Handle new user creation (Profile)
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing; -- For idempotency
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Trigger for reports_count (Simple counter, could be optimized later)
create or replace function public.update_reports_count()
returns trigger as $$
begin
    if (TG_OP = 'INSERT') then
        update public.profiles
        set reports_count = reports_count + 1
        where id = new.user_id;
    elsif (TG_OP = 'DELETE') then
        update public.profiles
        set reports_count = reports_count - 1
        where id = old.user_id;
    end if;
    return null;
end;
$$ language plpgsql security definer;

drop trigger if exists on_report_change on public.reports;
create trigger on_report_change
  after insert or delete on public.reports
  for each row execute procedure public.update_reports_count();


-- RLS POLICIES

-- Enable RLS (safe to re-run)
alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.reports enable row level security;
alter table public.report_images enable row level security;
alter table public.ai_analysis enable row level security;
alter table public.badges enable row level security;
alter table public.user_badges enable row level security;

-- Profiles: Public read, User update own
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
create policy "Public profiles are viewable by everyone." on public.profiles for select using (true);

drop policy if exists "Users can update own profile." on public.profiles;
create policy "Users can update own profile." on public.profiles for update using (auth.uid() = id);

-- Organizations: Public read
drop policy if exists "Organizations are viewable by everyone." on public.organizations;
create policy "Organizations are viewable by everyone." on public.organizations for select using (true);

-- Reports: Public read, User insert
drop policy if exists "Reports are viewable by everyone." on public.reports;
create policy "Reports are viewable by everyone." on public.reports for select using (true);

drop policy if exists "Authenticated users can insert reports." on public.reports;
create policy "Authenticated users can insert reports." on public.reports for insert with check (auth.uid() = user_id);

drop policy if exists "Users can update own reports." on public.reports;
create policy "Users can update own reports." on public.reports for update using (auth.uid() = user_id);

drop policy if exists "Users can delete own reports." on public.reports;
create policy "Users can delete own reports." on public.reports for delete using (auth.uid() = user_id);

-- Report Images: Public read, User insert related to own report
drop policy if exists "Report images are viewable by everyone." on public.report_images;
create policy "Report images are viewable by everyone." on public.report_images for select using (true);

drop policy if exists "Users can insert images for their reports." on public.report_images;
create policy "Users can insert images for their reports." on public.report_images for insert with check (
    exists ( select 1 from public.reports where id = report_images.report_id and user_id = auth.uid() )
);

-- AI Analysis: Public read
drop policy if exists "AI Analysis viewable by everyone." on public.ai_analysis;
create policy "AI Analysis viewable by everyone." on public.ai_analysis for select using (true);

-- Badges: Public read
drop policy if exists "Badges are viewable by everyone." on public.badges;
create policy "Badges are viewable by everyone." on public.badges for select using (true);

drop policy if exists "User badges are viewable by everyone." on public.user_badges;
create policy "User badges are viewable by everyone." on public.user_badges for select using (true);


-- STORAGE BUCKETS (via inserts into storage.buckets)
-- This usually works if the migration runs with service role privileges
insert into storage.buckets (id, name, public)
values 
  ('report-images', 'report-images', true),
  ('avatars', 'avatars', true),
  ('org-logos', 'org-logos', true)
on conflict (id) do nothing;

-- Storage Policies (Simplified for now - anyone can read, authenticated can upload)
create policy "Public Access" on storage.objects for select using ( bucket_id in ('report-images', 'avatars', 'org-logos') );
create policy "Authenticated Upload" on storage.objects for insert with check ( auth.role() = 'authenticated' );
