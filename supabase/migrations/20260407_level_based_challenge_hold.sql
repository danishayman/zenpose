-- Snapshot per-day challenge hold target so timing can vary by user level.
alter table public.daily_challenges
  add column if not exists target_hold_seconds integer;
