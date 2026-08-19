-- ============================================================
-- HIBEYA Akal Budi
-- Device-authenticated learner progress sync
--
-- Principles:
-- - Learner device has no Supabase Auth user.
-- - Device proves possession of opaque device token.
-- - Server derives child ownership from learner_devices.
-- - Revoked devices cannot submit progress.
-- - Duplicate offline sync is idempotent via session UUID.
-- ============================================================


-- ============================================================
-- 1. PRIVATE DEVICE VALIDATION HELPER
-- ============================================================

create or replace function
  private.get_valid_learner_device(
    p_device_id uuid,
    p_device_token text
  )
returns public.learner_devices
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device
    public.learner_devices%rowtype;

  v_token_hash text;
begin

  if p_device_id is null then
    raise exception
      'Invalid device';
  end if;


  if p_device_token is null
    or p_device_token !~ '^[a-f0-9]{64}$'
  then
    raise exception
      'Invalid device token';
  end if;


  v_token_hash :=
    encode(
      extensions.digest(
        p_device_token,
        'sha256'
      ),
      'hex'
    );


  select
    d.*
  into
    v_device
  from
    public.learner_devices as d
  where
    d.id = p_device_id
    and d.token_hash = v_token_hash
    and d.revoked_at is null
  limit 1;


  if not found then
    raise exception
      'Device not authorised';
  end if;


  return v_device;

end;
$$;


revoke all
on function
  private.get_valid_learner_device(
    uuid,
    text
  )
from public, anon, authenticated;


-- ============================================================
-- 2. DEVICE PROGRESS SYNC RPC
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
begin

  v_device :=
    private.get_valid_learner_device(
      p_device_id,
      p_device_token
    );


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


  if p_activity_version <= 0 then
    raise exception
      'Invalid activity version';
  end if;


  if p_started_at is null
    or p_completed_at is null
    or p_completed_at < p_started_at
  then
    raise exception
      'Invalid session timestamps';
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
  )

  on conflict (id)
  do nothing;


  update
    public.learner_devices
  set
    last_seen_at =
      now()
  where
    id =
      v_device.id;


  return
    p_session_id;

end;
$$;


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
