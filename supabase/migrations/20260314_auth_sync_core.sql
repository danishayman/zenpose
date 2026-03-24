-- Core auth + sync schema for ZenPose SRD parity.

create extension if not exists "pgcrypto";

create table if not exists public.pose_results (
  record_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  pose_name text,
  best_score double precision,
  hold_duration double precision,
  completed boolean,
  "timestamp" timestamptz,
  gamification_processed boolean not null default false,
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.user_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  current_streak integer not null default 0,
  longest_streak integer not null default 0,
  total_xp integer not null default 0,
  last_active_date text,
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.user_badges (
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_id text not null,
  unlocked_at timestamptz not null,
  source_pose_result_id text,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, badge_id)
);

create table if not exists public.daily_challenges (
  user_id uuid not null references auth.users(id) on delete cascade,
  date_key text not null,
  status text not null default 'in_progress',
  skip_count integer not null default 0,
  total_steps integer not null,
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default timezone('utc', now()),
  sequence_json jsonb not null default '[]'::jsonb,
  primary key (user_id, date_key)
);

create table if not exists public.daily_challenge_steps (
  user_id uuid not null references auth.users(id) on delete cascade,
  date_key text not null,
  step_index integer not null,
  pose_name text not null,
  status text not null default 'pending',
  best_score double precision,
  hold_duration double precision,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, date_key, step_index),
  foreign key (user_id, date_key)
    references public.daily_challenges(user_id, date_key)
    on delete cascade
);

alter table public.pose_results enable row level security;
alter table public.user_stats enable row level security;
alter table public.user_badges enable row level security;
alter table public.daily_challenges enable row level security;
alter table public.daily_challenge_steps enable row level security;

drop policy if exists "pose_results_owner_all" on public.pose_results;
create policy "pose_results_owner_all"
on public.pose_results
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "user_stats_owner_all" on public.user_stats;
create policy "user_stats_owner_all"
on public.user_stats
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "user_badges_owner_all" on public.user_badges;
create policy "user_badges_owner_all"
on public.user_badges
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "daily_challenges_owner_all" on public.daily_challenges;
create policy "daily_challenges_owner_all"
on public.daily_challenges
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "daily_challenge_steps_owner_all" on public.daily_challenge_steps;
create policy "daily_challenge_steps_owner_all"
on public.daily_challenge_steps
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
