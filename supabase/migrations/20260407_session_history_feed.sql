-- Session history feed support for practice/challenge source grouping.

alter table public.pose_results
  add column if not exists session_type text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'pose_results_session_type_check'
      and conrelid = 'public.pose_results'::regclass
  ) then
    alter table public.pose_results
      add constraint pose_results_session_type_check
      check (
        session_type is null
        or session_type in ('challenge', 'practice')
      );
  end if;
end $$;

create index if not exists idx_pose_results_user_session_time
  on public.pose_results (user_id, session_type, "timestamp" desc);

-- Keep cloud schema aligned with local challenge summary fields.
alter table public.daily_challenges
  add column if not exists session_avg_score double precision;

alter table public.daily_challenges
  add column if not exists session_calories double precision;

alter table public.daily_challenges
  add column if not exists session_feedback text;

alter table public.daily_challenges
  add column if not exists session_elapsed_seconds integer;
