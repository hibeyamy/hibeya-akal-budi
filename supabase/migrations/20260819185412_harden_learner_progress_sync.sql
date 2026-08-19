-- ============================================================
-- HIBEYA Akal Budi
-- Harden device-authenticated progress sync
--
-- Guarantees:
-- - Valid learner device required
-- - Revoked device rejected
-- - Child identity derived server-side
-- - Session IDs cannot cross child boundaries
-- - Legitimate retries are idempotent
-- - Existing session data cannot be mutated by retry
-- ============================================================


create or replace function
  public.sync_learner_session(
    p_device_id uuid,
    p_device_token text,
    p_session_id uuid,
    p_activity_id text,
    p_activity_version integer,
    p_started_at timestamptz,
    p_completed_at timestamptz,
    p_correct_count integer,
    p_incorrect_count integer,
    p_attempts integer,
    p_duration_seconds integer
  )
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device
    public.learner_devices%rowtype;

  v_existing_child_id uuid;
begin

  -- ----------------------------------------------------------
  -- Authenticate learner device.
  -- ----------------------------------------------------------

  v_device :=
    private.get_valid_learner_device(
      p_device_id,
      p_device_token
    );


  -- ----------------------------------------------------------
  -- Validate identifiers.
  -- ----------------------------------------------------------

  if p_session_id is null then
    raise exception
      'Session ID required';
  end if;


  if p_activity_id is null
    or char_length(
      btrim(
        p_activity_id
      )
    ) not between 1 and 150
  then
    raise exception
      'Invalid activity ID';
  end if;


  if p_activity_version is null
    or p_activity_version <= 0
  then
    raise exception
      'Invalid activity version';
  end if;


  -- ----------------------------------------------------------
  -- Validate timestamps.
  -- ----------------------------------------------------------

  if p_started_at is null
    or p_completed_at is null
    or p_completed_at < p_started_at
  then
    raise exception
      'Invalid session timestamps';
  end if;


  -- Prevent obviously unreasonable future timestamps.
  --
  -- Small clock skew is tolerated.

  if p_started_at >
      now() + interval '5 minutes'
    or p_completed_at >
      now() + interval '5 minutes'
  then
    raise exception
      'Session timestamp is in the future';
  end if;


  -- ----------------------------------------------------------
  -- Validate metrics.
  -- ----------------------------------------------------------

  if p_correct_count is null
    or p_incorrect_count is null
    or p_attempts is null
    or p_duration_seconds is null
  then
    raise exception
      'Session metrics required';
  end if;


  if p_correct_count < 0
    or p_incorrect_count < 0
    or p_attempts < 0
    or p_duration_seconds < 0
    or p_duration_seconds > 3600
  then
    raise exception
      'Invalid session metrics';
  end if;


  if p_attempts <>
    p_correct_count +
    p_incorrect_count
  then
    raise exception
      'Attempt totals do not match';
  end if;


  -- ----------------------------------------------------------
  -- Ownership-aware idempotency.
  --
  -- If this UUID already exists:
  --
  -- same child      -> legitimate retry
  -- different child -> reject collision
  --
  -- The retry does NOT modify the original record.
  -- ----------------------------------------------------------

  select
    ls.child_id
  into
    v_existing_child_id
  from
    public.learning_sessions as ls
  where
    ls.id = p_session_id;


  if found then

    if v_existing_child_id <>
      v_device.child_id
    then
      raise exception
        'Session ID already belongs to another learner';
    end if;


    update
      public.learner_devices
    set
      last_seen_at = now()
    where
      id = v_device.id;


    return
      p_session_id;

  end if;


  -- ----------------------------------------------------------
  -- Create session.
  --
  -- child_id is NEVER supplied by learner-web.
  -- It comes exclusively from the validated device.
  -- ----------------------------------------------------------

  insert into
    public.learning_sessions (
      id,
      child_id,
      activity_id,
      activity_version,
      started_at,
      completed_at,
      correct_count,
      incorrect_count,
      attempts,
      duration_seconds
    )
  values (
    p_session_id,
    v_device.child_id,
    btrim(
      p_activity_id
    ),
    p_activity_version,
    p_started_at,
    p_completed_at,
    p_correct_count,
    p_incorrect_count,
    p_attempts,
    p_duration_seconds
  );


  update
    public.learner_devices
  set
    last_seen_at = now()
  where
    id = v_device.id;


  return
    p_session_id;

end;
$$;


-- ============================================================
-- Explicit privileges
-- ============================================================

revoke all
on function
  public.sync_learner_session(
    uuid,
    text,
    uuid,
    text,
    integer,
    timestamptz,
    timestamptz,
    integer,
    integer,
    integer,
    integer
  )
from public, authenticated;


grant execute
on function
  public.sync_learner_session(
    uuid,
    text,
    uuid,
    text,
    integer,
    timestamptz,
    timestamptz,
    integer,
    integer,
    integer,
    integer
  )
to anon;


-- ============================================================
-- END
-- ============================================================
