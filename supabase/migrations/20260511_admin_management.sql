-- Admin management schema for users and pose-based exercise library.

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null default '',
  display_name text,
  role text not null default 'user' check (role in ('user', 'admin')),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) > 0),
  description text not null default '',
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.exercise_steps (
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  step_index integer not null check (step_index >= 0),
  pose_name text not null check (char_length(trim(pose_name)) > 0),
  hold_seconds integer not null default 20 check (hold_seconds > 0),
  rest_seconds integer not null default 30 check (rest_seconds >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (exercise_id, step_index)
);

create index if not exists idx_exercises_active
  on public.exercises (is_active, updated_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_user_profiles_updated_at on public.user_profiles;
create trigger set_user_profiles_updated_at
before update on public.user_profiles
for each row
execute function public.set_updated_at();

drop trigger if exists set_exercises_updated_at on public.exercises;
create trigger set_exercises_updated_at
before update on public.exercises
for each row
execute function public.set_updated_at();

drop trigger if exists set_exercise_steps_updated_at on public.exercise_steps;
create trigger set_exercise_steps_updated_at
before update on public.exercise_steps
for each row
execute function public.set_updated_at();

create or replace function public.sync_user_profile_from_auth()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  resolved_display_name text;
begin
  resolved_display_name :=
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(trim(split_part(new.email, '@', 1)), '')
    );

  insert into public.user_profiles (
    user_id,
    email,
    display_name,
    role,
    status
  )
  values (
    new.id,
    coalesce(new.email, ''),
    resolved_display_name,
    'user',
    'active'
  )
  on conflict (user_id) do update
    set email = excluded.email,
        display_name = coalesce(excluded.display_name, public.user_profiles.display_name),
        updated_at = timezone('utc', now());

  return new;
end;
$$;

drop trigger if exists sync_user_profile_on_auth_user on auth.users;
create trigger sync_user_profile_on_auth_user
after insert or update of email, raw_user_meta_data
on auth.users
for each row
execute function public.sync_user_profile_from_auth();

insert into public.user_profiles (user_id, email, display_name, role, status)
select
  u.id,
  coalesce(u.email, ''),
  coalesce(
    nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
    nullif(trim(u.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(split_part(u.email, '@', 1)), '')
  ),
  'user',
  'active'
from auth.users u
on conflict (user_id) do update
set
  email = excluded.email,
  display_name = coalesce(excluded.display_name, public.user_profiles.display_name),
  updated_at = timezone('utc', now());

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.user_profiles up
    where up.user_id = auth.uid()
      and up.role = 'admin'
      and up.status = 'active'
  );
$$;

create or replace function public.enforce_user_profile_mutation_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  active_admin_count integer;
begin
  if old.role = 'admin'
     and old.status = 'active'
     and (new.role <> 'admin' or new.status <> 'active') then
    select count(*)
      into active_admin_count
    from public.user_profiles
    where role = 'admin'
      and status = 'active'
      and user_id <> old.user_id;
    if active_admin_count = 0 then
      raise exception 'Cannot remove the last active admin.';
    end if;
  end if;

  if auth.uid() = old.user_id
     and (new.role <> old.role or new.status <> old.status)
     and not public.is_admin() then
    raise exception 'Users cannot update their own role or status.';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_user_profile_mutation on public.user_profiles;
create trigger enforce_user_profile_mutation
before update on public.user_profiles
for each row
execute function public.enforce_user_profile_mutation_rules();

create or replace function public.admin_update_user_profile(
  target_user_id uuid,
  new_role text,
  new_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  old_row public.user_profiles%rowtype;
  next_role text;
  next_status text;
begin
  if not public.is_admin() then
    raise exception 'Only admins can update users.';
  end if;

  next_role := lower(trim(new_role));
  next_status := lower(trim(new_status));

  if next_role not in ('user', 'admin') then
    raise exception 'Invalid role value: %', new_role;
  end if;
  if next_status not in ('active', 'inactive') then
    raise exception 'Invalid status value: %', new_status;
  end if;

  select *
    into old_row
  from public.user_profiles
  where user_id = target_user_id
  for update;

  if not found then
    raise exception 'User profile not found for id %', target_user_id;
  end if;

  if target_user_id = auth.uid() and (next_role <> 'admin' or next_status <> 'active') then
    raise exception 'Admins cannot demote or deactivate themselves.';
  end if;

  update public.user_profiles
  set role = next_role,
      status = next_status,
      updated_at = timezone('utc', now())
  where user_id = target_user_id;
end;
$$;

alter table public.user_profiles enable row level security;
alter table public.exercises enable row level security;
alter table public.exercise_steps enable row level security;

drop policy if exists "user_profiles_select" on public.user_profiles;
create policy "user_profiles_select"
on public.user_profiles
for select
using (
  auth.uid() = user_id
  or public.is_admin()
);

drop policy if exists "user_profiles_update" on public.user_profiles;
create policy "user_profiles_update"
on public.user_profiles
for update
using (
  auth.uid() = user_id
  or public.is_admin()
)
with check (
  auth.uid() = user_id
  or public.is_admin()
);

drop policy if exists "exercises_select_active_or_admin" on public.exercises;
create policy "exercises_select_active_or_admin"
on public.exercises
for select
using (
  is_active = true
  or public.is_admin()
);

drop policy if exists "exercises_admin_insert" on public.exercises;
create policy "exercises_admin_insert"
on public.exercises
for insert
with check (public.is_admin());

drop policy if exists "exercises_admin_update" on public.exercises;
create policy "exercises_admin_update"
on public.exercises
for update
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "exercises_admin_delete" on public.exercises;
create policy "exercises_admin_delete"
on public.exercises
for delete
using (public.is_admin());

drop policy if exists "exercise_steps_select_active_or_admin" on public.exercise_steps;
create policy "exercise_steps_select_active_or_admin"
on public.exercise_steps
for select
using (
  exists (
    select 1
    from public.exercises e
    where e.id = exercise_steps.exercise_id
      and (e.is_active = true or public.is_admin())
  )
);

drop policy if exists "exercise_steps_admin_insert" on public.exercise_steps;
create policy "exercise_steps_admin_insert"
on public.exercise_steps
for insert
with check (public.is_admin());

drop policy if exists "exercise_steps_admin_update" on public.exercise_steps;
create policy "exercise_steps_admin_update"
on public.exercise_steps
for update
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "exercise_steps_admin_delete" on public.exercise_steps;
create policy "exercise_steps_admin_delete"
on public.exercise_steps
for delete
using (public.is_admin());
