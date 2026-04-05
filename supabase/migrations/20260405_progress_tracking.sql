-- Progress tracking schema additions for ZenPose v6.

create table if not exists public.weekly_workout_goals (
  user_id uuid primary key references auth.users(id) on delete cascade,
  target_workouts integer not null default 3,
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.body_measurements (
  user_id uuid not null references auth.users(id) on delete cascade,
  metric_key text not null,
  value double precision not null,
  unit text not null,
  measured_at timestamptz not null,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, metric_key, measured_at)
);

alter table public.weekly_workout_goals enable row level security;
alter table public.body_measurements enable row level security;

drop policy if exists "weekly_workout_goals_owner_all" on public.weekly_workout_goals;
create policy "weekly_workout_goals_owner_all"
on public.weekly_workout_goals
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "body_measurements_owner_all" on public.body_measurements;
create policy "body_measurements_owner_all"
on public.body_measurements
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
