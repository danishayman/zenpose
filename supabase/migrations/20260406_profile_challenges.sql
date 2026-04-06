-- Monthly profile challenge state for join/claim lifecycle.

create table if not exists public.user_profile_challenges (
  user_id uuid not null references auth.users(id) on delete cascade,
  month_key text not null,
  challenge_id text not null,
  status text not null,
  joined_at timestamptz not null,
  completed_at timestamptz,
  claimed_at timestamptz,
  reward_badge_label text,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, month_key, challenge_id)
);

alter table public.user_profile_challenges enable row level security;

drop policy if exists "user_profile_challenges_owner_all" on public.user_profile_challenges;
create policy "user_profile_challenges_owner_all"
on public.user_profile_challenges
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
