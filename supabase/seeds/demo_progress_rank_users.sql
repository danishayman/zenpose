-- ZenPose rank-based demo progression seed.
-- Run this file after creating the 5 auth users.
--
-- Targets only:
--   bronze@example.com
--   silver@example.com
--   gold@example.com
--   emerald@example.com
--   diamond@example.com

begin;

do $$
declare
  expected_emails constant text[] := array[
    'bronze@example.com',
    'silver@example.com',
    'gold@example.com',
    'emerald@example.com',
    'diamond@example.com'
  ];
  missing_emails text[];
begin
  select array_agg(email)
  into missing_emails
  from (
    select e.email
    from unnest(expected_emails) as e(email)
    where not exists (
      select 1
      from auth.users u
      where lower(u.email) = e.email
    )
  ) missing;

  if missing_emails is not null and array_length(missing_emails, 1) > 0 then
    raise exception
      'Missing required rank demo users in auth.users: %',
      array_to_string(missing_emails, ', ');
  end if;
end;
$$;

create temporary table _rank_demo_users
on commit drop
as
select
  u.id as user_id,
  lower(u.email) as email,
  case lower(u.email)
    when 'bronze@example.com' then 'bronze'
    when 'silver@example.com' then 'silver'
    when 'gold@example.com' then 'gold'
    when 'emerald@example.com' then 'emerald'
    when 'diamond@example.com' then 'diamond'
  end as persona
from auth.users u
where lower(u.email) in (
  'bronze@example.com',
  'silver@example.com',
  'gold@example.com',
  'emerald@example.com',
  'diamond@example.com'
);

do $$
declare
  found_count integer;
begin
  select count(*) into found_count from _rank_demo_users;
  if found_count <> 5 then
    raise exception 'Expected 5 rank demo users, found %', found_count;
  end if;
end;
$$;

-- 1) Reset only targeted users.
delete from public.daily_challenge_steps
where user_id in (select user_id from _rank_demo_users);

delete from public.daily_challenges
where user_id in (select user_id from _rank_demo_users);

delete from public.user_profile_challenges
where user_id in (select user_id from _rank_demo_users);

delete from public.user_badges
where user_id in (select user_id from _rank_demo_users);

delete from public.pose_results
where user_id in (select user_id from _rank_demo_users);

delete from public.body_measurements
where user_id in (select user_id from _rank_demo_users);

delete from public.weekly_workout_goals
where user_id in (select user_id from _rank_demo_users);

delete from public.user_stats
where user_id in (select user_id from _rank_demo_users);

-- 2) Stats + weekly goals with rank-separated XP bands.
insert into public.user_stats (
  user_id,
  current_streak,
  longest_streak,
  total_xp,
  last_active_date,
  updated_at
)
select
  d.user_id,
  case d.persona
    when 'bronze' then 2
    when 'silver' then 5
    when 'gold' then 9
    when 'emerald' then 14
    when 'diamond' then 22
  end as current_streak,
  case d.persona
    when 'bronze' then 4
    when 'silver' then 9
    when 'gold' then 17
    when 'emerald' then 26
    when 'diamond' then 38
  end as longest_streak,
  case d.persona
    when 'bronze' then 600
    when 'silver' then 1800
    when 'gold' then 4500
    when 'emerald' then 9000
    when 'diamond' then 14000
  end as total_xp,
  to_char(current_date, 'YYYY-MM-DD') as last_active_date,
  timezone('utc', current_date + time '23:59:59') as updated_at
from _rank_demo_users d;

insert into public.weekly_workout_goals (
  user_id,
  target_workouts,
  updated_at
)
select
  d.user_id,
  case d.persona
    when 'bronze' then 2
    when 'silver' then 3
    when 'gold' then 4
    when 'emerald' then 5
    when 'diamond' then 7
  end as target_workouts,
  timezone('utc', current_date + time '23:59:58') as updated_at
from _rank_demo_users d;

-- 3) Practice history for dashboard/profile analytics.
with persona_config as (
  select *
  from (
    values
      ('bronze'::text, 10::int, 62::int, 280::int),
      ('silver', 18, 70, 420),
      ('gold', 28, 78, 560),
      ('emerald', 40, 86, 740),
      ('diamond', 54, 91, 920)
  ) v(persona, sessions_total, score_base, hold_base)
),
session_rows as (
  select
    d.user_id,
    d.persona,
    c.sessions_total,
    c.score_base,
    c.hold_base,
    gs as session_idx
  from _rank_demo_users d
  join persona_config c
    on c.persona = d.persona
  cross join lateral generate_series(1, c.sessions_total) gs
)
insert into public.pose_results (
  record_id,
  user_id,
  pose_name,
  best_score,
  hold_duration,
  completed,
  "timestamp",
  session_type,
  gamification_processed,
  updated_at
)
select
  'rank-' || s.persona || '-session-' || lpad(s.session_idx::text, 3, '0') as record_id,
  s.user_id,
  (array['Downdog', 'Tree', 'Plank', 'Warrior2', 'Goddess'])[1 + ((s.session_idx - 1) % 5)] as pose_name,
  (s.score_base + ((s.session_idx * 7) % 9))::double precision as best_score,
  (s.hold_base + ((s.session_idx * 31) % 190))::double precision as hold_duration,
  true as completed,
  timezone(
    'utc',
    (current_date + time '06:00')
      - ((s.sessions_total - s.session_idx) * interval '13 hour')
  ) as "timestamp",
  'practice'::text as session_type,
  true as gamification_processed,
  timezone(
    'utc',
    (current_date + time '06:05')
      - ((s.sessions_total - s.session_idx) * interval '13 hour')
  ) as updated_at
from session_rows s;

-- 4) Badge unlock snapshots.
with badge_map as (
  select *
  from (
    values
      ('bronze'::text, 'first_completion'::text, 8::int),
      ('silver', 'first_completion', 24),
      ('silver', 'sessions_5', 14),
      ('gold', 'first_completion', 32),
      ('gold', 'sessions_5', 28),
      ('gold', 'streak_3', 20),
      ('emerald', 'first_completion', 40),
      ('emerald', 'sessions_5', 36),
      ('emerald', 'sessions_25', 15),
      ('emerald', 'streak_7', 12),
      ('emerald', 'high_score_90', 9),
      ('diamond', 'first_completion', 60),
      ('diamond', 'sessions_5', 58),
      ('diamond', 'sessions_25', 41),
      ('diamond', 'streak_7', 39),
      ('diamond', 'streak_14', 28),
      ('diamond', 'high_score_90', 26),
      ('diamond', 'high_score_95', 20),
      ('diamond', 'high_score_98', 11)
  ) v(persona, badge_id, unlocked_days_ago)
)
insert into public.user_badges (
  user_id,
  badge_id,
  unlocked_at,
  source_pose_result_id,
  updated_at
)
select
  d.user_id,
  b.badge_id,
  timezone('utc', (current_date + time '21:00') - (b.unlocked_days_ago * interval '1 day')) as unlocked_at,
  null::text as source_pose_result_id,
  timezone('utc', (current_date + time '21:03') - (b.unlocked_days_ago * interval '1 day')) as updated_at
from _rank_demo_users d
join badge_map b
  on b.persona = d.persona;

-- 5) Body measurements trend (weight + body fat).
with plan as (
  select
    d.user_id,
    d.persona,
    metric.metric_key,
    metric.unit,
    6 as sample_count
  from _rank_demo_users d
  cross join (
    values
      ('body_weight'::text, 'kg'::text),
      ('body_fat', '%')
  ) metric(metric_key, unit)
),
rows as (
  select
    p.*,
    gs as sample_idx
  from plan p
  cross join lateral generate_series(1, p.sample_count) gs
)
insert into public.body_measurements (
  user_id,
  metric_key,
  value,
  unit,
  measured_at,
  updated_at
)
select
  r.user_id,
  r.metric_key,
  (
    case
      when r.metric_key = 'body_weight' then
        case r.persona
          when 'bronze' then 80.0 - ((r.sample_idx - 1) * 0.08)
          when 'silver' then 77.0 - ((r.sample_idx - 1) * 0.11)
          when 'gold' then 74.0 - ((r.sample_idx - 1) * 0.14)
          when 'emerald' then 71.5 - ((r.sample_idx - 1) * 0.10)
          when 'diamond' then 69.0 - ((r.sample_idx - 1) * 0.08)
        end
      else
        case r.persona
          when 'bronze' then 28.0 - ((r.sample_idx - 1) * 0.10)
          when 'silver' then 24.0 - ((r.sample_idx - 1) * 0.12)
          when 'gold' then 20.0 - ((r.sample_idx - 1) * 0.14)
          when 'emerald' then 17.0 - ((r.sample_idx - 1) * 0.08)
          when 'diamond' then 14.5 - ((r.sample_idx - 1) * 0.06)
        end
    end
  )::double precision as value,
  r.unit,
  timezone('utc', (current_date + time '08:30') - ((r.sample_count - r.sample_idx) * interval '6 day')) as measured_at,
  timezone('utc', (current_date + time '08:40') - ((r.sample_count - r.sample_idx) * interval '6 day')) as updated_at
from rows r;

-- 6) Today's daily challenge + step snapshots.
with today_values as (
  select
    d.user_id,
    d.persona,
    to_char(current_date, 'YYYY-MM-DD') as today_key,
    jsonb_build_array('Downdog', 'Tree', 'Plank', 'Warrior2', 'Goddess') as sequence_json
  from _rank_demo_users d
)
insert into public.daily_challenges (
  user_id,
  date_key,
  status,
  skip_count,
  total_steps,
  target_hold_seconds,
  started_at,
  completed_at,
  updated_at,
  sequence_json
)
select
  t.user_id,
  t.today_key,
  case
    when t.persona = 'bronze' then 'in_progress'
    else 'completed'
  end as status,
  case
    when t.persona = 'bronze' then 1
    else 0
  end as skip_count,
  5 as total_steps,
  case t.persona
    when 'bronze' then 20
    when 'silver' then 35
    else 45
  end as target_hold_seconds,
  timezone('utc', current_date + time '06:00') as started_at,
  case
    when t.persona = 'bronze' then null
    else timezone('utc', current_date + time '06:34')
  end as completed_at,
  timezone('utc', current_date + time '06:42') as updated_at,
  t.sequence_json
from today_values t;

with today_values as (
  select
    d.user_id,
    d.persona,
    to_char(current_date, 'YYYY-MM-DD') as today_key
  from _rank_demo_users d
),
steps as (
  select *
  from (
    values
      (0::int, 'Downdog'::text),
      (1, 'Tree'),
      (2, 'Plank'),
      (3, 'Warrior2'),
      (4, 'Goddess')
  ) v(step_index, pose_name)
)
insert into public.daily_challenge_steps (
  user_id,
  date_key,
  step_index,
  pose_name,
  status,
  best_score,
  hold_duration,
  updated_at
)
select
  t.user_id,
  t.today_key,
  s.step_index,
  s.pose_name,
  case
    when t.persona = 'bronze' and s.step_index in (0, 1) then 'completed'
    when t.persona = 'bronze' and s.step_index = 2 then 'skipped'
    when t.persona = 'bronze' then 'pending'
    else 'completed'
  end as status,
  case
    when t.persona = 'bronze' and s.step_index <= 1 then (70 + (s.step_index * 3))::double precision
    when t.persona = 'silver' then (79 + (s.step_index * 2))::double precision
    when t.persona = 'gold' then (84 + (s.step_index * 2))::double precision
    when t.persona = 'emerald' then (90 + s.step_index)::double precision
    else (94 + s.step_index)::double precision
  end as best_score,
  case
    when t.persona = 'bronze' and s.step_index <= 1 then (42 + (s.step_index * 5))::double precision
    when t.persona = 'silver' then (58 + (s.step_index * 5))::double precision
    when t.persona = 'gold' then (74 + (s.step_index * 6))::double precision
    when t.persona = 'emerald' then (95 + (s.step_index * 7))::double precision
    else (112 + (s.step_index * 8))::double precision
  end as hold_duration,
  timezone('utc', (current_date + time '06:12') + (s.step_index * interval '5 minute')) as updated_at
from today_values t
cross join steps s;

-- 7) Current-month challenge lifecycle snapshots.
with reward_labels as (
  select *
  from (
    values
      ('sessions_20'::text, 'Session Builder'::text),
      ('sessions_40', 'Session Keeper'),
      ('minutes_120', 'Flow Time 120'),
      ('minutes_300', 'Flow Time 300'),
      ('minutes_600', 'Flow Time 600'),
      ('score_90_x5', 'Precision 90 x5')
  ) v(challenge_id, reward_badge_label)
),
challenge_rows as (
  select
    d.user_id,
    d.persona,
    to_char(current_date, 'YYYY-MM') as month_key,
    r.challenge_id,
    r.reward_badge_label
  from _rank_demo_users d
  cross join reward_labels r
)
insert into public.user_profile_challenges (
  user_id,
  month_key,
  challenge_id,
  status,
  joined_at,
  completed_at,
  claimed_at,
  reward_badge_label,
  updated_at
)
select
  c.user_id,
  c.month_key,
  c.challenge_id,
  case
    when c.persona = 'bronze' then 'joined'
    when c.persona = 'silver' and c.challenge_id in ('sessions_20', 'minutes_120') then 'completed'
    when c.persona = 'gold' and c.challenge_id in ('sessions_20', 'minutes_120', 'score_90_x5') then 'completed'
    when c.persona = 'emerald' then 'completed'
    when c.persona = 'diamond' then 'completed'
    else 'joined'
  end as status,
  timezone(
    'utc',
    date_trunc('month', current_date::timestamp)
      + ((row_number() over (partition by c.user_id order by c.challenge_id) - 1) * interval '1 day')
      + interval '09:00'
  ) as joined_at,
  case
    when c.persona = 'bronze' then null
    when c.persona = 'silver' and c.challenge_id in ('sessions_20', 'minutes_120') then timezone('utc', (current_date + time '18:00') - interval '2 day')
    when c.persona = 'gold' and c.challenge_id in ('sessions_20', 'minutes_120', 'score_90_x5') then timezone('utc', (current_date + time '19:00') - interval '1 day')
    when c.persona in ('emerald', 'diamond') then timezone('utc', (current_date + time '19:30') - interval '1 day')
    else null
  end as completed_at,
  case
    when c.persona = 'emerald' then timezone('utc', (current_date + time '20:00') - interval '1 day')
    when c.persona = 'diamond' then timezone('utc', (current_date + time '20:10') - interval '1 day')
    else null
  end as claimed_at,
  case
    when c.persona in ('emerald', 'diamond') then c.reward_badge_label
    when c.persona = 'gold' and c.challenge_id in ('sessions_20', 'minutes_120', 'score_90_x5') then c.reward_badge_label
    when c.persona = 'silver' and c.challenge_id in ('sessions_20', 'minutes_120') then c.reward_badge_label
    else null
  end as reward_badge_label,
  timezone('utc', current_date + time '22:00') as updated_at
from challenge_rows c;

commit;

-- Verification snippets (optional):
-- select u.email, us.total_xp
-- from public.user_stats us
-- join auth.users u on u.id = us.user_id
-- where lower(u.email) in (
--   'bronze@example.com',
--   'silver@example.com',
--   'gold@example.com',
--   'emerald@example.com',
--   'diamond@example.com'
-- )
-- order by us.total_xp;
--
-- select u.email, count(*) as sessions
-- from public.pose_results pr
-- join auth.users u on u.id = pr.user_id
-- where lower(u.email) in (
--   'bronze@example.com',
--   'silver@example.com',
--   'gold@example.com',
--   'emerald@example.com',
--   'diamond@example.com'
-- )
-- group by u.email
-- order by u.email;
--
-- select u.email, count(*) as challenge_rows
-- from public.user_profile_challenges upc
-- join auth.users u on u.id = upc.user_id
-- where lower(u.email) in (
--   'bronze@example.com',
--   'silver@example.com',
--   'gold@example.com',
--   'emerald@example.com',
--   'diamond@example.com'
-- )
-- group by u.email
-- order by u.email;
