-- =========================================================
-- Pantry Tracker (SnackTrack) - Complete Database Schema
-- Stack: Supabase Postgres + RLS Policies + Triggers
-- =========================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============ USERS & PROFILES ============
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  login_count int not null default 0,
  has_completed_onboarding boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view and manage their own profile"
  on public.profiles for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ============ SUBSCRIPTIONS ============
do $$ begin
  create type subscription_tier as enum ('free', 'plus', 'pro');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type subscription_provider as enum ('stripe', 'apple', 'google');
exception
  when duplicate_object then null;
end $$;

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  tier subscription_tier not null default 'free',
  provider subscription_provider,
  provider_subscription_id text,        -- Stripe subscription id / store purchase token
  status text not null default 'active', -- active, past_due, canceled
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists subscriptions_user_id_idx on public.subscriptions(user_id);

alter table public.subscriptions enable row level security;

create policy "Users can view their own subscription"
  on public.subscriptions for select
  using (auth.uid() = user_id);

create policy "Service role manages subscriptions"
  on public.subscriptions for all
  using (auth.jwt() ->> 'role' = 'service_role');

-- Rolling usage counters, reset monthly by a scheduled Edge Function / cron
create table if not exists public.usage_counters (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  period_start date not null default date_trunc('month', now())::date,
  scans_used int not null default 0,
  recipes_generated int not null default 0
);

alter table public.usage_counters enable row level security;

create policy "Users can view their own usage counters"
  on public.usage_counters for select
  using (auth.uid() = user_id);

create policy "Service role manages usage counters"
  on public.usage_counters for all
  using (auth.jwt() ->> 'role' = 'service_role');

-- ============ PANTRY ITEMS ============
create table if not exists public.pantry_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  normalized_name text generated always as (lower(trim(name))) stored,
  barcode text,
  category text,
  quantity numeric default 1,
  unit text,
  expiry_date date,
  expiry_source text default 'predicted', -- predicted | manual | label_ocr
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pantry_items_user_expiry_idx on public.pantry_items(user_id, expiry_date);
create index if not exists pantry_items_normalized_name_idx on public.pantry_items(normalized_name);

alter table public.pantry_items enable row level security;

create policy "Users manage their own pantry items"
  on public.pantry_items for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============ RECIPES (Shared Cache & AI Dataset) ============
create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  normalized_name text generated always as (lower(trim(name))) stored,
  ingredients jsonb not null,       -- [{ "name": "eggs", "quantity": "2" }, ...]
  instructions jsonb not null,      -- ["step 1", "step 2", ...]
  primary_ingredient text,          -- the pantry item this was generated for
  source text not null default 'gemini', -- gemini | manual | future in-house model
  generation_count int not null default 1, -- how many times this recipe was served
  created_at timestamptz not null default now()
);

create unique index if not exists recipes_normalized_name_primary_idx
  on public.recipes(normalized_name, primary_ingredient);

alter table public.recipes enable row level security;

create policy "Authenticated users can read cached recipes"
  on public.recipes for select
  using (auth.role() = 'authenticated');

create policy "Service role manages recipe cache"
  on public.recipes for all
  using (auth.jwt() ->> 'role' = 'service_role');

-- ============ FAVORITE RECIPES ============
create table if not exists public.favorite_recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  recipe_snapshot jsonb not null,   -- denormalized JSON copy at time of favoriting
  created_at timestamptz not null default now(),
  unique(user_id, recipe_id)
);

alter table public.favorite_recipes enable row level security;

create policy "Users manage their own favorite recipes"
  on public.favorite_recipes for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============ SHOPPING LIST ============
create table if not exists public.shopping_list_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  quantity numeric default 1,
  unit text,
  is_checked boolean not null default false,
  source text default 'manual',  -- manual | recipe | low_stock
  created_at timestamptz not null default now()
);

alter table public.shopping_list_items enable row level security;

create policy "Users manage their own shopping list items"
  on public.shopping_list_items for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============ HELPER RPC FUNCTIONS ============
create or replace function public.increment_usage_scans(p_user_id uuid)
returns void language plpgsql security definer as $$
begin
  insert into public.usage_counters (user_id, period_start, scans_used, recipes_generated)
  values (p_user_id, date_trunc('month', now())::date, 1, 0)
  on conflict (user_id) do update
  set scans_used = public.usage_counters.scans_used + 1;
end;
$$;
