-- Snapshot hold target per daily challenge exercise step.
alter table public.daily_challenge_steps
  add column if not exists target_hold_seconds integer;

with challenge_targets as (
  select
    c.user_id,
    c.date_key,
    case
      when coalesce(s.total_xp, 0) <= 999 then 20
      when coalesce(s.total_xp, 0) <= 2999 then 30
      when coalesce(s.total_xp, 0) <= 6999 then 35
      when coalesce(s.total_xp, 0) <= 11999 then 40
      else 45
    end as target_hold_seconds
  from public.daily_challenges c
  left join public.user_stats s on s.user_id = c.user_id
)
update public.daily_challenges c
set target_hold_seconds = t.target_hold_seconds
from challenge_targets t
where t.user_id = c.user_id
  and t.date_key = c.date_key
  and c.target_hold_seconds is distinct from t.target_hold_seconds;

update public.daily_challenge_steps s
set target_hold_seconds = c.target_hold_seconds
from public.daily_challenges c
where c.user_id = s.user_id
  and c.date_key = s.date_key
  and s.target_hold_seconds is distinct from c.target_hold_seconds;
