-- ZenPose demo progression seed
-- Resets and reseeds only:
--   beginner@example.com
--   intermediate@example.com
--   pro@example.com
--
-- Run in Supabase SQL Editor with a role that can write to auth-backed tables.

begin;

do $$
declare
  expected_emails constant text[] := array[
    'beginner@example.com',
    'intermediate@example.com',
    'pro@example.com'
  ];
  missing_emails text[];
begin
  select array_agg(email)
  into missing_emails
  from (
    select expected_email.email as email
    from unnest(expected_emails) as expected_email(email)
    where not exists (
      select 1
      from auth.users u
      where lower(u.email) = expected_email.email
    )
  ) missing;

  if missing_emails is not null and array_length(missing_emails, 1) > 0 then
    raise exception
      'Missing required demo users in auth.users: %',
      array_to_string(missing_emails, ', ');
  end if;
end;
$$;

create temporary table _demo_users
on commit drop
as
select
  u.id as user_id,
  lower(u.email) as email,
  case lower(u.email)
    when 'beginner@example.com' then 'beginner'
    when 'intermediate@example.com' then 'intermediate'
    when 'pro@example.com' then 'pro'
  end as persona
from auth.users u
where lower(u.email) in (
  'beginner@example.com',
  'intermediate@example.com',
  'pro@example.com'
);

do $$
declare
  found_count integer;
begin
  select count(*) into found_count from _demo_users;
  if found_count <> 3 then
    raise exception 'Expected 3 demo users, found %', found_count;
  end if;
end;
$$;

-- 1) Hard reset existing progression rows for only the demo users.
delete from public.daily_challenge_steps
where user_id in (select user_id from _demo_users);

delete from public.daily_challenges
where user_id in (select user_id from _demo_users);

delete from public.user_profile_challenges
where user_id in (select user_id from _demo_users);

delete from public.user_badges
where user_id in (select user_id from _demo_users);

delete from public.pose_results
where user_id in (select user_id from _demo_users);

delete from public.body_measurements
where user_id in (select user_id from _demo_users);

delete from public.weekly_workout_goals
where user_id in (select user_id from _demo_users);

delete from public.user_stats
where user_id in (select user_id from _demo_users);

-- 2) User stats + weekly goals by persona.
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
    when 'beginner' then 2
    when 'intermediate' then 6
    when 'pro' then 18
  end as current_streak,
  case d.persona
    when 'beginner' then 4
    when 'intermediate' then 12
    when 'pro' then 31
  end as longest_streak,
  case d.persona
    when 'beginner' then 480
    when 'intermediate' then 2680
    when 'pro' then 9620
  end as total_xp,
  to_char(
    current_date -
      case d.persona
        when 'beginner' then interval '1 day'
        when 'intermediate' then interval '0 day'
        when 'pro' then interval '0 day'
      end,
    'YYYY-MM-DD'
  ) as last_active_date,
  timezone('utc', current_date + time '23:59:59') as updated_at
from _demo_users d;

insert into public.weekly_workout_goals (
  user_id,
  target_workouts,
  updated_at
)
select
  d.user_id,
  case d.persona
    when 'beginner' then 2
    when 'intermediate' then 4
    when 'pro' then 7
  end as target_workouts,
  timezone('utc', current_date + time '23:59:58') as updated_at
from _demo_users d;

-- 3) Pose results (drives profile activity + dashboard analytics).
with persona_day_counts as (
  select *
  from (
    values
      ('beginner'::text, array[1,0,1,1,0,1,1,0,1,0,1,1]::int[]),
      ('intermediate', array[2,1,2,1,1,2,1,1,2,1,1,2,1,1,2,1,1,2,0,1]::int[]),
      ('pro', array[3,2,3,2,2,3,2,3,2,2,3,2,3,2,2,3,2,3,2,2,3,2,3,2]::int[])
  ) v(persona, day_counts)
),
session_slots as (
  select
    d.user_id,
    d.persona,
    dc.day_idx,
    dc.sessions_on_day,
    gs as session_in_day
  from _demo_users d
  join persona_day_counts pdc
    on pdc.persona = d.persona
  cross join lateral unnest(pdc.day_counts) with ordinality as dc(sessions_on_day, day_idx)
  cross join lateral generate_series(1, dc.sessions_on_day) gs
),
sessions as (
  select
    s.*,
    row_number() over (
      partition by s.persona
      order by s.day_idx desc, s.session_in_day asc
    ) as session_idx
  from session_slots s
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
  'demo-' || s.persona || '-d' || lpad(s.day_idx::text, 2, '0') || '-s' || s.session_in_day::text as record_id,
  s.user_id,
  (array['Downdog', 'Goddess', 'Plank', 'Tree', 'Warrior2'])[1 + ((s.session_idx - 1) % 5)] as pose_name,
  case s.persona
    when 'beginner' then (64 + ((s.session_idx * 9 + s.day_idx * 3) % 22))::double precision
    when 'intermediate' then (75 + ((s.session_idx * 7 + s.day_idx * 2) % 20))::double precision
    when 'pro' then (88 + ((s.session_idx * 5 + s.day_idx) % 11))::double precision
  end as best_score,
  case s.persona
    when 'beginner' then (260 + ((s.session_idx * 23 + s.day_idx * 7) % 220))::double precision
    when 'intermediate' then (480 + ((s.session_idx * 29 + s.day_idx * 11) % 420))::double precision
    when 'pro' then (900 + ((s.session_idx * 37 + s.day_idx * 13) % 780))::double precision
  end as hold_duration,
  true as completed,
  case s.persona
    when 'beginner' then
      timezone(
        'utc',
        ((current_date - (s.day_idx - 1)::int) + time '19:00')
          + ((s.session_in_day - 1) * interval '2 hour 10 minute')
          + (((s.day_idx + s.session_in_day) % 3) * interval '17 minute')
      )
    when 'intermediate' then
      timezone(
        'utc',
        ((current_date - (s.day_idx - 1)::int) + time '12:30')
          + ((s.session_in_day - 1) * interval '2 hour 25 minute')
          + (((s.day_idx + s.session_in_day) % 4) * interval '12 minute')
      )
    when 'pro' then
      timezone(
        'utc',
        ((current_date - (s.day_idx - 1)::int) + time '06:00')
          + ((s.session_in_day - 1) * interval '1 hour 35 minute')
          + (((s.day_idx + s.session_in_day) % 5) * interval '10 minute')
      )
  end as "timestamp",
  'practice'::text as session_type,
  true as gamification_processed,
  case s.persona
    when 'beginner' then
      timezone(
        'utc',
        ((current_date - (s.day_idx - 1)::int) + time '19:00')
          + ((s.session_in_day - 1) * interval '2 hour 10 minute')
          + (((s.day_idx + s.session_in_day) % 3) * interval '17 minute')
          + interval '4 minute'
      )
    when 'intermediate' then
      timezone(
        'utc',
        ((current_date - (s.day_idx - 1)::int) + time '12:30')
          + ((s.session_in_day - 1) * interval '2 hour 25 minute')
          + (((s.day_idx + s.session_in_day) % 4) * interval '12 minute')
          + interval '4 minute'
      )
    when 'pro' then
      timezone(
        'utc',
        ((current_date - (s.day_idx - 1)::int) + time '06:00')
          + ((s.session_in_day - 1) * interval '1 hour 35 minute')
          + (((s.day_idx + s.session_in_day) % 5) * interval '10 minute')
          + interval '4 minute'
      )
  end as updated_at
from sessions s;

-- 4) Badge unlocks by persona.
with badge_map as (
  select *
  from (
    values
      ('beginner'::text, 'first_completion'::text, 8::int),
      ('intermediate', 'first_completion', 45),
      ('intermediate', 'sessions_5', 30),
      ('intermediate', 'streak_3', 24),
      ('intermediate', 'high_score_90', 14),
      ('pro', 'first_completion', 90),
      ('pro', 'sessions_5', 86),
      ('pro', 'sessions_25', 60),
      ('pro', 'streak_3', 84),
      ('pro', 'streak_7', 72),
      ('pro', 'streak_14', 58),
      ('pro', 'high_score_90', 52),
      ('pro', 'high_score_95', 41),
      ('pro', 'high_score_98', 25)
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
  timezone(
    'utc',
    (current_date + time '21:00')
      - (b.unlocked_days_ago * interval '1 day')
  ) as unlocked_at,
  null::text as source_pose_result_id,
  timezone(
    'utc',
    (current_date + time '21:03')
      - (b.unlocked_days_ago * interval '1 day')
  ) as updated_at
from _demo_users d
join badge_map b
  on b.persona = d.persona;

-- 5) Body measurements (weight + body fat trends).
with measure_plan as (
  select
    d.user_id,
    d.persona,
    metric.metric_key,
    metric.unit,
    case d.persona
      when 'beginner' then 4
      when 'intermediate' then 8
      when 'pro' then 12
    end as sample_count,
    case d.persona
      when 'beginner' then interval '10 day'
      when 'intermediate' then interval '7 day'
      when 'pro' then interval '5 day'
    end as step_span
  from _demo_users d
  cross join (
    values
      ('body_weight'::text, 'kg'::text),
      ('body_fat', '%')
  ) metric(metric_key, unit)
),
measure_rows as (
  select
    p.*,
    gs as sample_idx
  from measure_plan p
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
          when 'beginner' then
            78.0 - ((r.sample_idx - 1) * 0.10) + (((r.sample_idx % 3) - 1) * 0.05)
          when 'intermediate' then
            74.5 - ((r.sample_idx - 1) * 0.18) + (((r.sample_idx % 4) - 2) * 0.03)
          when 'pro' then
            70.0 - ((r.sample_idx - 1) * 0.12) + (((r.sample_idx % 5) - 2) * 0.02)
        end
      when r.metric_key = 'body_fat' then
        case r.persona
          when 'beginner' then
            27.0 - ((r.sample_idx - 1) * 0.12) + (((r.sample_idx % 2) - 0.5) * 0.10)
          when 'intermediate' then
            22.0 - ((r.sample_idx - 1) * 0.20) + (((r.sample_idx % 3) - 1) * 0.06)
          when 'pro' then
            16.5 - ((r.sample_idx - 1) * 0.10) + (((r.sample_idx % 4) - 1.5) * 0.04)
        end
    end
  )::double precision as value,
  r.unit,
  timezone(
    'utc',
    (current_date + time '08:30')
      - ((r.sample_count - r.sample_idx) * r.step_span)
  ) as measured_at,
  timezone(
    'utc',
    (current_date + time '08:40')
      - ((r.sample_count - r.sample_idx) * r.step_span)
  ) as updated_at
from measure_rows r;

-- 6) Daily challenge (today) + steps by persona.
with today_values as (
  select
    d.user_id,
    d.persona,
    to_char(current_date, 'YYYY-MM-DD') as today_key,
    jsonb_build_array('Downdog', 'Tree', 'Plank', 'Warrior2', 'Goddess') as sequence_json
  from _demo_users d
)
insert into public.daily_challenges (
  user_id,
  date_key,
  status,
  skip_count,
  total_steps,
  started_at,
  completed_at,
  updated_at,
  sequence_json
)
select
  t.user_id,
  t.today_key,
  case t.persona
    when 'beginner' then 'in_progress'
    else 'completed'
  end as status,
  case t.persona
    when 'beginner' then 1
    else 0
  end as skip_count,
  5 as total_steps,
  timezone('utc', current_date + time '06:00') as started_at,
  case t.persona
    when 'beginner' then null
    else timezone('utc', current_date + time '06:38')
  end as completed_at,
  timezone('utc', current_date + time '06:45') as updated_at,
  t.sequence_json
from today_values t;

with today_values as (
  select
    d.user_id,
    d.persona,
    to_char(current_date, 'YYYY-MM-DD') as today_key
  from _demo_users d
),
step_template as (
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
    when t.persona = 'beginner' and s.step_index in (0, 1) then 'completed'
    when t.persona = 'beginner' and s.step_index = 2 then 'skipped'
    when t.persona = 'beginner' then 'pending'
    else 'completed'
  end as status,
  case
    when t.persona = 'beginner' and s.step_index = 0 then 73.0
    when t.persona = 'beginner' and s.step_index = 1 then 76.0
    when t.persona = 'intermediate' then (82 + (s.step_index * 2))::double precision
    when t.persona = 'pro' then (93 + s.step_index)::double precision
    else null
  end as best_score,
  case
    when t.persona = 'beginner' and s.step_index = 0 then 48.0
    when t.persona = 'beginner' and s.step_index = 1 then 52.0
    when t.persona = 'intermediate' then (72 + (s.step_index * 6))::double precision
    when t.persona = 'pro' then (104 + (s.step_index * 8))::double precision
    else null
  end as hold_duration,
  timezone(
    'utc',
    (current_date + time '06:10') + (s.step_index * interval '6 minute')
  ) as updated_at
from today_values t
cross join step_template s;

-- 7) Current-month profile challenge states.
with reward_labels as (
  select *
  from (
    values
      ('sessions_20'::text, 'Session Builder'::text),
      ('sessions_40', 'Session Keeper'),
      ('minutes_120', 'Flow Time 120'),
      ('minutes_300', 'Flow Time 300'),
      ('minutes_600', 'Flow Time 600'),
      ('score_90_x5', 'Precision 90 x5'),
      ('score_90_x10', 'Precision 90 x10'),
      ('score_95_x3', 'Alignment 95'),
      ('score_95_x6', 'Alignment 95 Master')
  ) v(challenge_id, reward_badge_label)
),
challenge_rows as (
  select
    d.user_id,
    d.persona,
    to_char(current_date, 'YYYY-MM') as month_key,
    r.challenge_id,
    r.reward_badge_label
  from _demo_users d
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
    when c.persona = 'beginner' then 'joined'
    when c.persona = 'intermediate' and c.challenge_id in ('sessions_20', 'minutes_120', 'score_90_x5') then 'completed'
    when c.persona = 'pro' and c.challenge_id in ('sessions_40', 'minutes_600') then 'joined'
    else 'completed'
  end as status,
  timezone(
    'utc',
    date_trunc('month', current_date::timestamp)
      + ((row_number() over (
        partition by c.user_id
        order by c.challenge_id
      ) - 1) * interval '1 day')
      + interval '9 hour'
  ) as joined_at,
  case
    when c.persona = 'beginner' then null
    when c.persona = 'intermediate' and c.challenge_id in ('sessions_20', 'minutes_120', 'score_90_x5') then
      timezone('utc', (current_date + time '19:00') - interval '2 day')
    when c.persona = 'pro' and c.challenge_id in ('sessions_40', 'minutes_600') then
      null
    else timezone('utc', (current_date + time '20:00') - interval '1 day')
  end as completed_at,
  case
    when c.persona = 'pro' and c.challenge_id not in ('sessions_40', 'minutes_600') then
      timezone('utc', (current_date + time '20:10') - interval '1 day')
    else null
  end as claimed_at,
  case
    when c.persona = 'beginner' then null
    when c.persona = 'intermediate' and c.challenge_id in ('sessions_20', 'minutes_120', 'score_90_x5') then c.reward_badge_label
    when c.persona = 'pro' and c.challenge_id not in ('sessions_40', 'minutes_600') then c.reward_badge_label
    else null
  end as reward_badge_label,
  timezone('utc', current_date + time '22:00') as updated_at
from challenge_rows c;

commit;

-- Optional verification snippets (run after seed):
-- select u.email, count(*) as workouts
-- from public.pose_results pr
-- join auth.users u on u.id = pr.user_id
-- where lower(u.email) in ('beginner@example.com', 'intermediate@example.com', 'pro@example.com')
-- group by u.email
-- order by u.email;
--
-- select u.email, us.current_streak, us.longest_streak, us.total_xp, wg.target_workouts
-- from public.user_stats us
-- join public.weekly_workout_goals wg on wg.user_id = us.user_id
-- join auth.users u on u.id = us.user_id
-- where lower(u.email) in ('beginner@example.com', 'intermediate@example.com', 'pro@example.com')
-- order by u.email;
--
-- select u.email, upc.status, count(*) as challenge_rows
-- from public.user_profile_challenges upc
-- join auth.users u on u.id = upc.user_id
-- where lower(u.email) in ('beginner@example.com', 'intermediate@example.com', 'pro@example.com')
-- group by u.email, upc.status
-- order by u.email, upc.status;
