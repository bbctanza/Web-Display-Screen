-- Complete Setup Script for Scrollable Announcements
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard/project/_/sql)

-- ==========================================
-- 1. Tables & Security
-- ==========================================

-- 1.1 Create the announcements table
create table if not exists public.announcements (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  image_url text not null,
  title text default 'Untitled Announcement',
  display_duration integer default 10,
  transition_type text default 'fade',
  active boolean default true,
  order_index integer default 0
);

-- Enable RLS for announcements
alter table public.announcements enable row level security;

-- 1.2 Create the Settings Table
create table if not exists public.settings (
  id integer primary key default 1,
  refresh_interval integer default 5, -- in minutes
  default_duration integer default 10, -- in seconds
  security_enabled boolean default false,
  admin_password text, -- Nullable to allow "Setup Mode" if blank
  constraint single_row check (id = 1)
);

-- Enable RLS for settings
alter table public.settings enable row level security;

-- ==========================================
-- 2. Row Level Security Policies
-- ==========================================

-- Cleanup old policies to ensure idempotency
drop policy if exists "Public Annoucements are viewable by everyone" on public.announcements;
drop policy if exists "Anyone can upload announcements" on public.announcements;
drop policy if exists "Anyone can update announcements" on public.announcements;
drop policy if exists "Anyone can delete announcements" on public.announcements;

-- Public Access Policies for Announcements
create policy "Public Annoucements are viewable by everyone"
on public.announcements for select
to public
using ( true );

create policy "Anyone can upload announcements"
on public.announcements for insert
to public
with check ( true );

create policy "Anyone can update announcements"
on public.announcements for update
to public
using ( true );

create policy "Anyone can delete announcements"
on public.announcements for delete
to public
using ( true );

-- Settings Policies
drop policy if exists "Public Settings are viewable by everyone" on public.settings;
drop policy if exists "Anyone can update settings" on public.settings;

create policy "Public Settings are viewable by everyone"
on public.settings for select
to public
using ( true );

create policy "Anyone can update settings"
on public.settings for update
to public
using ( true );

-- ==========================================
-- 3. Functions (RPC) for Security
-- ==========================================

-- 3.1 Function to check if password is set (without revealing it)
create or replace function is_password_set()
returns boolean
language plpgsql
security definer
as $$
declare
  has_pass boolean;
begin
  select (admin_password is not null and admin_password <> '') into has_pass
  from public.settings
  where id = 1;
  
  return coalesce(has_pass, false);
end;
$$;

-- 3.2 Function to verify password safely (prevents leaking password hash)
create or replace function verify_admin_password(attempt text)
returns boolean
language plpgsql
security definer
as $$
declare
  is_correct boolean;
begin
  select (admin_password = attempt) into is_correct
  from public.settings
  where id = 1;
  
  return coalesce(is_correct, false);
end;
$$;

-- 3.3 Function to securely change password
create or replace function change_admin_password(current_password text, new_password text)
returns boolean
language plpgsql
security definer
as $$
declare
  is_valid boolean;
begin
  -- 1. Check if the current password matches
  select (admin_password = current_password) into is_valid
  from public.settings
  where id = 1;

  if is_valid is not true then
    return false;
  else
    update public.settings
    set admin_password = new_password
    where id = 1;
    return true;
  end if;
end;
$$;

-- ==========================================
-- 4. Initial Data
-- ==========================================

insert into public.settings (id, refresh_interval, default_duration, security_enabled, admin_password)
values (1, 5, 10, false, null)
on conflict (id) do nothing;

-- ==========================================
-- 5. Storage Setup
-- ==========================================

insert into storage.buckets (id, name, public)
values ('announcements', 'announcements', true)
on conflict (id) do update
set public = true; 

drop policy if exists "Public Access" on storage.objects;
drop policy if exists "Public Upload" on storage.objects;

create policy "Public Access"
on storage.objects for select
to public
using ( bucket_id = 'announcements' );

create policy "Public Upload"
on storage.objects for insert
to public
with check ( bucket_id = 'announcements' );
