-- Snapshot hold target per daily challenge exercise step.
alter table public.daily_challenge_steps
  add column if not exists target_hold_seconds integer;

update public.daily_challenges c
set target_hold_seconds = case
  when coalesce(s.total_xp, 0) <= 999 then 20
  when coalesce(s.total_xp, 0) <= 2999 then 30
  when coalesce(s.total_xp, 0) <= 6999 then 35
  when coalesce(s.total_xp, 0) <= 11999 then 40
  else 45
end
from public.user_stats s
where s.user_id = c.user_id;

update public.daily_challenge_steps s
set target_hold_seconds = coalesce(c.target_hold_seconds, 45)
from public.daily_challenges c
where c.user_id = s.user_id
  and c.date_key = s.date_key
  and s.target_hold_seconds is distinct from coalesce(c.target_hold_seconds, 45);
