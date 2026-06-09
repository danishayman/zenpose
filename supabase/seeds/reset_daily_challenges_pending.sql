-- Reset all current daily challenge progress so every account starts untouched.
--
-- Run this after all_accounts_full_progress.sql if the seeded accounts already
-- show completed/resumed daily challenge progress on the Home screen.

begin;

update public.daily_challenges
set
  status = 'in_progress',
  skip_count = 0,
  completed_at = null,
  updated_at = timezone('utc', now()),
  session_avg_score = null,
  session_calories = null,
  session_feedback = null,
  session_elapsed_seconds = null;

update public.daily_challenge_steps
set
  status = 'pending',
  best_score = null,
  hold_duration = null,
  updated_at = timezone('utc', now());

commit;
