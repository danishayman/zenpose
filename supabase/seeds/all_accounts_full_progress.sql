-- ZenPose all-accounts full progress seed.
--
-- Purpose:
--   Seed every current auth.users account with complete, graph-friendly demo data.
--   This includes all bundled pose exercises so the Progress > Exercises tab has
--   enough history to show trend sparklines and "5-session trend" summaries.
--
-- What this resets:
--   All progress/gamification rows for every current auth.users account.
--   Do not run this against production accounts that contain real user progress.
--
-- Rank assignment:
--   1) If the email contains bronze/silver/gold/emerald/diamond, that rank wins.
--   2) Otherwise, existing public.user_stats.total_xp is used when present.
--   3) Otherwise, accounts are distributed evenly across the five ranks.

begin;

create temporary table _all_account_users
on commit drop
as
with auth_rows as (
  select
    u.id as user_id,
    lower(coalesce(u.email, '')) as email,
    coalesce(
      nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''),
      nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
      nullif(trim(u.raw_user_meta_data ->> 'display_name'), ''),
      nullif(trim(split_part(coalesce(u.email, ''), '@', 1)), ''),
      'ZenPose User'
    ) as display_name,
    coalesce(us.total_xp, 0) as existing_xp,
    row_number() over (
      order by u.created_at nulls last, coalesce(u.email, ''), u.id
    ) as account_idx
  from auth.users u
  left join public.user_stats us
    on us.user_id = u.id
),
ranked as (
  select
    a.*,
    case
      when a.email like '%diamond%' then 'diamond'
      when a.email like '%emerald%' then 'emerald'
      when a.email like '%gold%' then 'gold'
      when a.email like '%silver%' then 'silver'
      when a.email like '%bronze%' then 'bronze'
      when a.existing_xp >= 12000 then 'diamond'
      when a.existing_xp >= 7000 then 'emerald'
      when a.existing_xp >= 3000 then 'gold'
      when a.existing_xp >= 1000 then 'silver'
      when a.existing_xp > 0 then 'bronze'
      else (
        array['bronze', 'silver', 'gold', 'emerald', 'diamond']
      )[1 + (((a.account_idx - 1) % 5)::int)]
    end as rank_name
  from auth_rows a
)
select
  r.*,
  case r.rank_name
    when 'bronze' then 0
    when 'silver' then 1
    when 'gold' then 2
    when 'emerald' then 3
    else 4
  end as rank_order
from ranked r;

do $$
declare
  account_count integer;
begin
  select count(*) into account_count from _all_account_users;
  if account_count = 0 then
    raise exception 'No auth.users accounts found to seed.';
  end if;
end;
$$;

create temporary table _rank_config
on commit drop
as
select *
from (
  values
    ('bronze'::text, 850::int, 4::int, 7::int, 3::int, 6::int, 66.0::double precision, 24.0::double precision),
    ('silver', 2400, 8, 13, 4, 7, 74.0, 34.0),
    ('gold', 5600, 15, 22, 5, 8, 82.0, 46.0),
    ('emerald', 9800, 24, 34, 6, 10, 88.0, 60.0),
    ('diamond', 15400, 38, 52, 7, 12, 92.0, 74.0)
) as v(
  rank_name,
  total_xp,
  current_streak,
  longest_streak,
  weekly_goal,
  sessions_per_pose,
  score_base,
  hold_base
);

create temporary table _seed_poses
on commit drop
as
select *
from (
  values
    (1::int, 'Chair'::text),
    (2, 'Downdog'),
    (3, 'Goddess'),
    (4, 'Half Moon'),
    (5, 'Plank'),
    (6, 'Tree'),
    (7, 'Warrior II'),
    (8, 'Cobra'),
    (9, 'High Lunge'),
    (10, 'Triangle')
) as v(pose_order, pose_name);

-- Keep public user_profiles aligned with auth.users, but preserve existing
-- role/status values for accounts that are already managed.
insert into public.user_profiles (
  user_id,
  email,
  display_name,
  role,
  status,
  created_at,
  updated_at
)
select
  user_id,
  email,
  display_name,
  'user',
  'active',
  timezone('utc', now()),
  timezone('utc', now())
from _all_account_users
on conflict (user_id) do update
set
  email = excluded.email,
  display_name = coalesce(excluded.display_name, public.user_profiles.display_name),
  updated_at = timezone('utc', now());

-- Seed active exercise routines for daily challenge selection. Fixed UUIDs make
-- this idempotent without requiring a unique name constraint.
create temporary table _seed_exercises
on commit drop
as
select *
from (
  values
    (
      '11111111-1111-4111-8111-111111111111'::uuid,
      'Complete Foundations'::text,
      'A full beginner-friendly circuit covering strength, balance, and standing alignment.'::text,
      1::int
    ),
    (
      '22222222-2222-4222-8222-222222222222'::uuid,
      'Strength and Mobility Flow',
      'A stronger flow focused on core stability, spinal extension, and lower-body control.',
      2
    ),
    (
      '33333333-3333-4333-8333-333333333333'::uuid,
      'Balance Builder',
      'A balance-focused routine for single-leg control and lateral alignment.',
      3
    ),
    (
      '44444444-4444-4444-8444-444444444444'::uuid,
      'Full ZenPose Circuit',
      'A complete ten-pose practice that touches every bundled ZenPose exercise.',
      4
    )
) as v(exercise_id, name, description, sort_order);

insert into public.exercises (
  id,
  name,
  description,
  is_active,
  created_by,
  created_at,
  updated_at
)
select
  s.exercise_id,
  s.name,
  s.description,
  true,
  (select user_id from _all_account_users order by account_idx limit 1),
  timezone('utc', now()),
  timezone('utc', now())
from _seed_exercises s
on conflict (id) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = true,
  updated_at = timezone('utc', now());

delete from public.exercise_steps
where exercise_id in (select exercise_id from _seed_exercises);

insert into public.exercise_steps (
  exercise_id,
  step_index,
  pose_name,
  hold_seconds,
  rest_seconds,
  created_at,
  updated_at
)
select
  exercise_id,
  step_index,
  pose_name,
  hold_seconds,
  rest_seconds,
  timezone('utc', now()),
  timezone('utc', now())
from (
  values
    ('11111111-1111-4111-8111-111111111111'::uuid, 0, 'Chair'::text, 25, 20),
    ('11111111-1111-4111-8111-111111111111'::uuid, 1, 'Tree', 25, 20),
    ('11111111-1111-4111-8111-111111111111'::uuid, 2, 'Warrior II', 30, 20),
    ('11111111-1111-4111-8111-111111111111'::uuid, 3, 'Triangle', 30, 20),
    ('11111111-1111-4111-8111-111111111111'::uuid, 4, 'Plank', 25, 30),
    ('22222222-2222-4222-8222-222222222222'::uuid, 0, 'Downdog', 30, 20),
    ('22222222-2222-4222-8222-222222222222'::uuid, 1, 'Plank', 35, 25),
    ('22222222-2222-4222-8222-222222222222'::uuid, 2, 'Cobra', 30, 20),
    ('22222222-2222-4222-8222-222222222222'::uuid, 3, 'High Lunge', 35, 25),
    ('22222222-2222-4222-8222-222222222222'::uuid, 4, 'Chair', 30, 30),
    ('33333333-3333-4333-8333-333333333333'::uuid, 0, 'Tree', 30, 25),
    ('33333333-3333-4333-8333-333333333333'::uuid, 1, 'Half Moon', 35, 30),
    ('33333333-3333-4333-8333-333333333333'::uuid, 2, 'Triangle', 30, 25),
    ('33333333-3333-4333-8333-333333333333'::uuid, 3, 'Warrior II', 35, 25),
    ('33333333-3333-4333-8333-333333333333'::uuid, 4, 'Goddess', 35, 30),
    ('44444444-4444-4444-8444-444444444444'::uuid, 0, 'Chair', 30, 20),
    ('44444444-4444-4444-8444-444444444444'::uuid, 1, 'Downdog', 35, 20),
    ('44444444-4444-4444-8444-444444444444'::uuid, 2, 'Goddess', 35, 20),
    ('44444444-4444-4444-8444-444444444444'::uuid, 3, 'Half Moon', 35, 25),
    ('44444444-4444-4444-8444-444444444444'::uuid, 4, 'Plank', 35, 25),
    ('44444444-4444-4444-8444-444444444444'::uuid, 5, 'Tree', 35, 25),
    ('44444444-4444-4444-8444-444444444444'::uuid, 6, 'Warrior II', 40, 25),
    ('44444444-4444-4444-8444-444444444444'::uuid, 7, 'Cobra', 35, 20),
    ('44444444-4444-4444-8444-444444444444'::uuid, 8, 'High Lunge', 40, 25),
    ('44444444-4444-4444-8444-444444444444'::uuid, 9, 'Triangle', 40, 30)
) as s(exercise_id, step_index, pose_name, hold_seconds, rest_seconds);

-- Reset graph/progress rows for all seeded accounts.
delete from public.xp_penalty_ledger
where user_id in (select user_id from _all_account_users);

delete from public.daily_challenge_steps
where user_id in (select user_id from _all_account_users);

delete from public.daily_challenges
where user_id in (select user_id from _all_account_users);

delete from public.user_profile_challenges
where user_id in (select user_id from _all_account_users);

delete from public.user_badges
where user_id in (select user_id from _all_account_users);

delete from public.pose_results
where user_id in (select user_id from _all_account_users);

delete from public.body_measurements
where user_id in (select user_id from _all_account_users);

delete from public.weekly_workout_goals
where user_id in (select user_id from _all_account_users);

delete from public.user_stats
where user_id in (select user_id from _all_account_users);

insert into public.user_stats (
  user_id,
  current_streak,
  longest_streak,
  total_xp,
  last_active_date,
  updated_at
)
select
  u.user_id,
  c.current_streak,
  c.longest_streak,
  c.total_xp,
  case
    when u.rank_name = 'bronze' then to_char(current_date - interval '2 days', 'YYYY-MM-DD')
    else to_char(current_date, 'YYYY-MM-DD')
  end,
  timezone('utc', current_date + time '23:58')
from _all_account_users u
join _rank_config c
  on c.rank_name = u.rank_name;

insert into public.weekly_workout_goals (
  user_id,
  target_workouts,
  updated_at
)
select
  u.user_id,
  c.weekly_goal,
  timezone('utc', current_date + time '23:57')
from _all_account_users u
join _rank_config c
  on c.rank_name = u.rank_name;

-- Completed practice sessions. Every pose has at least 6 rows per user, which
-- is the minimum needed by ProgressAnalyticsService.hasEnoughTrendData.
with session_rows as (
  select
    u.user_id,
    u.account_idx,
    u.rank_name,
    u.rank_order,
    c.sessions_per_pose,
    c.score_base,
    c.hold_base,
    p.pose_order,
    p.pose_name,
    gs.session_idx
  from _all_account_users u
  join _rank_config c
    on c.rank_name = u.rank_name
  cross join _seed_poses p
  cross join lateral generate_series(1, c.sessions_per_pose) as gs(session_idx)
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
  'all-accounts-' || s.user_id::text || '-pose-' || s.pose_order::text || '-session-' || lpad(s.session_idx::text, 2, '0'),
  s.user_id,
  s.pose_name,
  round(
    least(
      99.0,
      s.score_base
        + (s.session_idx * 1.55)
        + ((s.pose_order % 4) * 0.9)
        + ((s.account_idx % 3) - 1)
    )::numeric,
    1
  )::double precision as best_score,
  round(
    least(
      115.0,
      s.hold_base
        + (s.session_idx * 2.8)
        + ((s.pose_order % 5) * 1.6)
        + (s.rank_order * 1.7)
    )::numeric,
    1
  )::double precision as hold_duration,
  true,
  case
    when s.rank_name = 'bronze' then
      timezone(
        'utc',
        ((current_date - interval '2 days') + time '06:00')
          - ((s.sessions_per_pose - s.session_idx) * interval '2 days')
          - (((s.pose_order + s.account_idx) % 4) * interval '1 day')
          + (s.pose_order * interval '7 minutes')
          + (s.session_idx * interval '3 minutes')
      )
    else
      timezone(
        'utc',
        (current_date + time '06:00')
          - ((s.sessions_per_pose - s.session_idx) * interval '2 days')
          - (((s.pose_order + s.account_idx) % 6) * interval '1 day')
          + (s.rank_order * interval '38 minutes')
          + (s.pose_order * interval '7 minutes')
          + (s.session_idx * interval '3 minutes')
      )
  end as "timestamp",
  'practice',
  true,
  case
    when s.rank_name = 'bronze' then
      timezone(
        'utc',
        ((current_date - interval '2 days') + time '06:05')
          - ((s.sessions_per_pose - s.session_idx) * interval '2 days')
          - (((s.pose_order + s.account_idx) % 4) * interval '1 day')
          + (s.pose_order * interval '7 minutes')
          + (s.session_idx * interval '3 minutes')
      )
    else
      timezone(
        'utc',
        (current_date + time '06:05')
          - ((s.sessions_per_pose - s.session_idx) * interval '2 days')
          - (((s.pose_order + s.account_idx) % 6) * interval '1 day')
          + (s.rank_order * interval '38 minutes')
          + (s.pose_order * interval '7 minutes')
          + (s.session_idx * interval '3 minutes')
      )
  end as updated_at
from session_rows s;

with badge_map as (
  select *
  from (
    values
      ('bronze'::text, 'first_completion'::text, 24::int),
      ('bronze', 'sessions_5', 22),
      ('bronze', 'sessions_25', 12),
      ('bronze', 'streak_3', 5),
      ('silver', 'first_completion', 34),
      ('silver', 'sessions_5', 31),
      ('silver', 'sessions_25', 20),
      ('silver', 'streak_3', 14),
      ('silver', 'streak_7', 6),
      ('silver', 'high_score_90', 3),
      ('gold', 'first_completion', 42),
      ('gold', 'sessions_5', 39),
      ('gold', 'sessions_25', 29),
      ('gold', 'streak_3', 25),
      ('gold', 'streak_7', 17),
      ('gold', 'streak_14', 4),
      ('gold', 'high_score_90', 10),
      ('gold', 'high_score_95', 2),
      ('emerald', 'first_completion', 58),
      ('emerald', 'sessions_5', 55),
      ('emerald', 'sessions_25', 43),
      ('emerald', 'streak_3', 37),
      ('emerald', 'streak_7', 28),
      ('emerald', 'streak_14', 12),
      ('emerald', 'high_score_90', 18),
      ('emerald', 'high_score_95', 8),
      ('emerald', 'high_score_98', 2),
      ('diamond', 'first_completion', 70),
      ('diamond', 'sessions_5', 66),
      ('diamond', 'sessions_25', 54),
      ('diamond', 'streak_3', 48),
      ('diamond', 'streak_7', 39),
      ('diamond', 'streak_14', 25),
      ('diamond', 'high_score_90', 30),
      ('diamond', 'high_score_95', 18),
      ('diamond', 'high_score_98', 6)
  ) v(rank_name, badge_id, unlocked_days_ago)
)
insert into public.user_badges (
  user_id,
  badge_id,
  unlocked_at,
  source_pose_result_id,
  updated_at
)
select
  u.user_id,
  b.badge_id,
  timezone('utc', (current_date + time '20:30') - (b.unlocked_days_ago * interval '1 day')),
  null::text,
  timezone('utc', (current_date + time '20:35') - (b.unlocked_days_ago * interval '1 day'))
from _all_account_users u
join badge_map b
  on b.rank_name = u.rank_name;

-- Body metrics for the Measures tab. Latest samples trend down gently to look
-- realistic for active users without pretending every rank has the same body.
with measure_plan as (
  select
    u.user_id,
    u.account_idx,
    u.rank_name,
    metric.metric_key,
    metric.unit,
    gs.sample_idx
  from _all_account_users u
  cross join (
    values
      ('body_weight'::text, 'kg'::text),
      ('body_fat', '%')
  ) metric(metric_key, unit)
  cross join lateral generate_series(1, 12) as gs(sample_idx)
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
  m.user_id,
  m.metric_key,
  round(
    (
      case
        when m.metric_key = 'body_weight' then
          case m.rank_name
            when 'bronze' then 82.0
            when 'silver' then 77.0
            when 'gold' then 73.5
            when 'emerald' then 70.5
            else 67.5
          end
          + ((m.account_idx % 4) * 0.7)
          - (m.sample_idx * 0.16)
        else
          case m.rank_name
            when 'bronze' then 28.5
            when 'silver' then 24.5
            when 'gold' then 21.0
            when 'emerald' then 18.0
            else 15.5
          end
          + ((m.account_idx % 3) * 0.25)
          - (m.sample_idx * 0.10)
      end
    )::numeric,
    1
  )::double precision,
  m.unit,
  timezone(
    'utc',
    (current_date + time '08:20') - ((12 - m.sample_idx) * interval '7 days')
  ),
  timezone(
    'utc',
    (current_date + time '08:25') - ((12 - m.sample_idx) * interval '7 days')
  )
from measure_plan m;

-- Today's daily challenge. Higher ranks complete cleaner, longer sessions.
with today_values as (
  select
    u.user_id,
    u.rank_name,
    u.rank_order,
    c.score_base,
    case u.rank_name
      when 'bronze' then 20
      when 'silver' then 30
      when 'gold' then 35
      when 'emerald' then 40
      else 45
    end as target_hold_seconds,
    to_char(current_date, 'YYYY-MM-DD') as date_key,
    jsonb_build_array('Downdog', 'Tree', 'Plank', 'Warrior II', 'Goddess') as sequence_json
  from _all_account_users u
  join _rank_config c
    on c.rank_name = u.rank_name
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
  sequence_json,
  session_avg_score,
  session_calories,
  session_feedback,
  session_elapsed_seconds
)
select
  t.user_id,
  t.date_key,
  case when t.rank_name = 'bronze' then 'in_progress' else 'completed' end,
  case when t.rank_name = 'bronze' then 1 else 0 end,
  5,
  t.target_hold_seconds,
  timezone('utc', current_date + time '06:10'),
  case when t.rank_name = 'bronze' then null else timezone('utc', current_date + time '06:48') end,
  timezone('utc', current_date + time '06:52'),
  t.sequence_json,
  case when t.rank_name = 'bronze' then null else least(99.0, t.score_base + 8.0) end,
  case when t.rank_name = 'bronze' then null else round((t.target_hold_seconds * 5 * 0.08)::numeric, 1)::double precision end,
  case
    when t.rank_name = 'bronze' then null
    when t.rank_name = 'silver' then 'Good control with room to hold transitions longer.'
    when t.rank_name = 'gold' then 'Strong consistency across the flow.'
    when t.rank_name = 'emerald' then 'Excellent alignment and stable pacing.'
    else 'Elite control, smooth transitions, and long stable holds.'
  end,
  case when t.rank_name = 'bronze' then null else 2280 end
from today_values t;

with today_values as (
  select
    u.user_id,
    u.rank_name,
    u.rank_order,
    c.score_base,
    case u.rank_name
      when 'bronze' then 20
      when 'silver' then 30
      when 'gold' then 35
      when 'emerald' then 40
      else 45
    end as target_hold_seconds,
    to_char(current_date, 'YYYY-MM-DD') as date_key
  from _all_account_users u
  join _rank_config c
    on c.rank_name = u.rank_name
),
steps as (
  select *
  from (
    values
      (0::int, 'Downdog'::text),
      (1, 'Tree'),
      (2, 'Plank'),
      (3, 'Warrior II'),
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
  t.date_key,
  s.step_index,
  s.pose_name,
  case
    when t.rank_name = 'bronze' and s.step_index <= 2 then 'completed'
    when t.rank_name = 'bronze' and s.step_index = 3 then 'skipped'
    when t.rank_name = 'bronze' then 'pending'
    else 'completed'
  end,
  case
    when t.rank_name = 'bronze' and s.step_index = 4 then null
    else round(least(99.0, t.score_base + 3 + (s.step_index * 1.4))::numeric, 1)::double precision
  end,
  case
    when t.rank_name = 'bronze' and s.step_index = 4 then null
    else round((t.target_hold_seconds + (s.step_index * 2.5) + (t.rank_order * 1.5))::numeric, 1)::double precision
  end,
  timezone('utc', (current_date + time '06:15') + (s.step_index * interval '6 minutes'))
from today_values t
cross join steps s;

-- Current-month profile challenge rows. Insert all templates because the app
-- chooses a deterministic subset per month; unused rows simply sit harmlessly.
with challenge_templates as (
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
    u.user_id,
    u.rank_name,
    u.rank_order,
    to_char(current_date, 'YYYY-MM') as month_key,
    c.challenge_id,
    c.reward_badge_label
  from _all_account_users u
  cross join challenge_templates c
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
    when c.rank_name = 'bronze' then 'joined'
    when c.rank_name = 'silver' and c.challenge_id in ('sessions_20', 'score_90_x5') then 'completed'
    when c.rank_name = 'gold' and c.challenge_id in ('sessions_20', 'sessions_40', 'score_90_x5', 'score_95_x3') then 'completed'
    when c.rank_name = 'emerald' and c.challenge_id <> 'minutes_600' then 'completed'
    when c.rank_name = 'diamond' and c.challenge_id <> 'minutes_600' then 'completed'
    else 'joined'
  end,
  timezone(
    'utc',
    date_trunc('month', current_date::timestamp)
      + (((row_number() over (partition by c.user_id order by c.challenge_id) - 1)::int) * interval '1 day')
      + interval '9 hours'
  ),
  case
    when c.rank_name = 'bronze' then null
    when c.rank_name = 'silver' and c.challenge_id in ('sessions_20', 'score_90_x5') then timezone('utc', (current_date + time '18:00') - interval '2 days')
    when c.rank_name = 'gold' and c.challenge_id in ('sessions_20', 'sessions_40', 'score_90_x5', 'score_95_x3') then timezone('utc', (current_date + time '18:30') - interval '1 day')
    when c.rank_name in ('emerald', 'diamond') and c.challenge_id <> 'minutes_600' then timezone('utc', (current_date + time '19:00') - interval '1 day')
    else null
  end,
  case
    when c.rank_name in ('gold', 'emerald', 'diamond')
      and c.challenge_id in ('sessions_20', 'score_90_x5', 'score_95_x3') then timezone('utc', (current_date + time '20:00') - interval '1 day')
    when c.rank_name = 'diamond' and c.challenge_id in ('sessions_40', 'score_90_x10', 'score_95_x6') then timezone('utc', (current_date + time '20:15') - interval '1 day')
    else null
  end,
  case
    when c.rank_name = 'bronze' then null
    when c.rank_name = 'silver' and c.challenge_id in ('sessions_20', 'score_90_x5') then c.reward_badge_label
    when c.rank_name = 'gold' and c.challenge_id in ('sessions_20', 'sessions_40', 'score_90_x5', 'score_95_x3') then c.reward_badge_label
    when c.rank_name in ('emerald', 'diamond') and c.challenge_id <> 'minutes_600' then c.reward_badge_label
    else null
  end,
  timezone('utc', current_date + time '22:00')
from challenge_rows c;

commit;

-- Optional verification snippets:
--
-- select u.email, us.total_xp,
--   case
--     when us.total_xp <= 999 then 'bronze'
--     when us.total_xp <= 2999 then 'silver'
--     when us.total_xp <= 6999 then 'gold'
--     when us.total_xp <= 11999 then 'emerald'
--     else 'diamond'
--   end as seeded_rank,
--   count(pr.record_id) as practice_rows,
--   count(distinct pr.pose_name) as poses_seeded
-- from auth.users u
-- join public.user_stats us on us.user_id = u.id
-- left join public.pose_results pr on pr.user_id = u.id
-- group by u.email, us.total_xp
-- order by seeded_rank, u.email;
--
-- select pose_name, count(*) as rows
-- from public.pose_results
-- group by pose_name
-- order by pose_name;
--
-- select e.name, count(es.step_index) as steps
-- from public.exercises e
-- join public.exercise_steps es on es.exercise_id = e.id
-- where e.id in (
--   '11111111-1111-4111-8111-111111111111',
--   '22222222-2222-4222-8222-222222222222',
--   '33333333-3333-4333-8333-333333333333',
--   '44444444-4444-4444-8444-444444444444'
-- )
-- group by e.name
-- order by e.name;
