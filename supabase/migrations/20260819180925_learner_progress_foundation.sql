-- ============================================================
-- HIBEYA Akal Budi
-- Learner progress foundation
--
-- Principles:
-- - Children do not have authentication accounts.
-- - Progress belongs to a parent-owned child profile.
-- - Store learning summaries, not unnecessary behavioural logs.
-- - Client-generated UUID provides idempotent offline sync.
-- - RLS protects every child session.
-- ============================================================


-- ============================================================
-- 1. LEARNING SESSIONS
-- ============================================================

create table public.learning_sessions (
  id uuid primary key,

  child_id uuid
    not null
    references public.children(id)
    on delete cascade,

  activity_id text
    not null
    check (
      char_length(btrim(activity_id))
        between 1 and 150
    ),

  activity_version integer
    not null
    check (
      activity_version > 0
    ),

  started_at timestamptz
    not null,

  completed_at timestamptz
    not null,

  correct_count integer
    not null
    check (
      correct_count >= 0
    ),

  incorrect_count integer
    not null
    check (
      incorrect_count >= 0
    ),

  attempts integer
    not null
    check (
      attempts >= 0
    ),

  duration_seconds integer
    not null
    check (
      duration_seconds >= 0
      and duration_seconds <= 3600
    ),

  created_at timestamptz
    not null
    default now(),

  check (
    completed_at >= started_at
  ),

  check (
    attempts =
      correct_count +
      incorrect_count
  )
);


create index
  learning_sessions_child_id_idx
on public.learning_sessions(
  child_id
);


create index
  learning_sessions_child_activity_idx
on public.learning_sessions(
  child_id,
  activity_id
);


create index
  learning_sessions_child_completed_idx
on public.learning_sessions(
  child_id,
  completed_at desc
);


-- ============================================================
-- 2. ROW LEVEL SECURITY
-- ============================================================

alter table public.learning_sessions
  enable row level security;


-- ============================================================
-- 3. TABLE PRIVILEGES
-- ============================================================

revoke all
on table public.learning_sessions
from anon, authenticated;


grant select, insert
on table public.learning_sessions
to authenticated;


grant select, insert, update, delete
on table public.learning_sessions
to service_role;


-- ============================================================
-- 4. PARENT READ POLICY
-- ============================================================

create policy
  "Parents can read own child learning sessions"
on public.learning_sessions
for select
to authenticated
using (
  exists (
    select 1
    from public.children
    where public.children.id =
      learning_sessions.child_id
    and public.children.parent_id =
      (
        select auth.uid()
      )
  )
);


-- ============================================================
-- 5. PARENT INSERT POLICY
-- ============================================================

create policy
  "Parents can create learning sessions for own children"
on public.learning_sessions
for insert
to authenticated
with check (
  exists (
    select 1
    from public.children
    where public.children.id =
      learning_sessions.child_id
    and public.children.parent_id =
      (
        select auth.uid()
      )
  )
);


-- ============================================================
-- 6. IMPORTANT IMMUTABILITY RULE
-- ============================================================
--
-- No UPDATE or DELETE privilege is granted to authenticated.
--
-- Once a completed learning session is synchronised, normal
-- browser clients cannot rewrite its historical result.
--
-- Duplicate offline pushes use the same client-generated UUID
-- and are handled idempotently by the application.
-- ============================================================


-- ============================================================
-- END
-- ============================================================
