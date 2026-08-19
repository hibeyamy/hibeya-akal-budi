-- ============================================================
-- HIBEYA Akal Budi
-- Validate learner-device token
--
-- Purpose:
-- - Learner devices authenticate with an opaque device token.
-- - Raw token is never stored.
-- - Revoked devices fail validation.
-- - Anonymous clients can only validate possession of a token;
--   they cannot enumerate learner devices.
-- ============================================================


create or replace function
  public.validate_learner_device(
    p_device_id uuid,
    p_device_token text
  )
returns table (
  valid boolean,
  child_id uuid
)
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
    return query
    select
      false,
      null::uuid;

    return;
  end if;


  if p_device_token is null
    or p_device_token !~ '^[a-f0-9]{64}$'
  then
    return query
    select
      false,
      null::uuid;

    return;
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
    *
  into
    v_device
  from
    public.learner_devices as d
  where
    d.id =
      p_device_id

    and d.token_hash =
      v_token_hash

    and d.revoked_at
      is null

  limit 1;


  if not found then
    return query
    select
      false,
      null::uuid;

    return;
  end if;


  update
    public.learner_devices
  set
    last_seen_at =
      now()
  where
    id =
      v_device.id;


  return query
  select
    true,
    v_device.child_id;

end;
$$;


revoke all
on function
  public.validate_learner_device(
    uuid,
    text
  )
from public, authenticated;


grant execute
on function
  public.validate_learner_device(
    uuid,
    text
  )
to anon;


-- ============================================================
-- END
-- ============================================================
