-- XP punishment ledger for idempotent rank-scaled deductions.

create table if not exists public.xp_penalty_ledger (
  user_id uuid not null references auth.users(id) on delete cascade,
  date_key text not null,
  reason text not null,
  source_key text not null default '',
  xp_delta integer not null,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, date_key, reason, source_key)
);

alter table public.xp_penalty_ledger enable row level security;

drop policy if exists "xp_penalty_ledger_owner_all" on public.xp_penalty_ledger;
create policy "xp_penalty_ledger_owner_all"
on public.xp_penalty_ledger
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
