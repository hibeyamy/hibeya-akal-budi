-- ============================================================
-- HIBEYA Akal Budi
-- Harden learner-device activation
--
-- Improvements:
-- - Cryptographically generated activation codes
-- - Anonymous exchange rate limiting
-- - Failed attempts are recorded without personal identifiers
-- - Single-use activation preserved
-- - Device tokens remain random 256-bit secrets
-- ============================================================


-- ============================================================
-- 1. ACTIVATION ATTEMPT BUCKETS
-- ============================================================
--
-- This is deliberately coarse.
--
-- We do NOT collect:
-- - IP address
-- - device fingerprint
-- - location
-- - browser identity
--
-- For this first version, the database enforces a global
-- anonymous exchange budget per short time window.
--
-- This protects development/public exposure without introducing
-- additional personal-data collection.
-- ============================================================

create table public.learner_activation_rate_limits (
  window_started_at timestamptz
    primary key,

  attempt_count integer
    not null
    default 0
    check (
      attempt_count >= 0
    ),

  created_at timestamptz
    not null
    default now()
);


alter table
  public.learner_activation_rate_limits
enable row level security;


revoke all
on table public.learner_activation_rate_limits
from public, anon, authenticated;


grant select, insert, update, delete
on table public.learner_activation_rate_limits
to service_role;


-- ============================================================
-- 2. PRIVATE CRYPTOGRAPHIC SIX-DIGIT CODE GENERATOR
-- ============================================================

create or replace function
  private.generate_activation_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_bytes bytea;
  v_number bigint;
begin

  v_bytes :=
    extensions.gen_random_bytes(4);


  v_number :=
      get_byte(v_bytes, 0)::bigint
        * 16777216
    + get_byte(v_bytes, 1)::bigint
        * 65536
    + get_byte(v_bytes, 2)::bigint
        * 256
    + get_byte(v_bytes, 3)::bigint;


  return lpad(
    (
      v_number % 1000000
    )::text,
    6,
    '0'
  );

end;
$$;


revoke all
on function
  private.generate_activation_code()
from public, anon, authenticated;


-- ============================================================
-- 3. PRIVATE RATE-LIMIT CHECK
-- ============================================================
--
-- Development policy:
-- maximum 30 anonymous exchanges per minute across the project.
--
-- This is intentionally conservative and does not use
-- identifiers such as IP addresses.
--
-- Production may move this boundary to an Edge Function or
-- another dedicated rate-limiting layer.
-- ============================================================

create or replace function
  private.consume_activation_attempt()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_window timestamptz;
  v_count integer;
begin

  v_window :=
    date_trunc(
      'minute',
      now()
    );


  insert into
    public.learner_activation_rate_limits (
      window_started_at,
      attempt_count
    )
  values (
    v_window,
    1
  )

  on conflict (
    window_started_at
  )

  do update
  set
    attempt_count =
      public.learner_activation_rate_limits.attempt_count
      + 1

  returning
    attempt_count
  into
    v_count;


  if v_count > 30 then
    raise exception
      'Too many activation attempts. Try again shortly.';
  end if;


  delete from
    public.learner_activation_rate_limits
  where
    window_started_at
      <
    now() - interval '1 hour';

end;
$$;


revoke all
on function
  private.consume_activation_attempt()
from public, anon, authenticated;


-- ============================================================
-- 4. REPLACE PARENT ACTIVATION-CODE GENERATOR
-- ============================================================

create or replace function
  public.create_learner_device_activation(
    p_child_id uuid
  )
returns table (
  activation_code text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parent_id uuid;
  v_code text;
  v_expires_at timestamptz;
  v_attempt integer;
begin

  if auth.uid() is null then
    raise exception
      'Authentication required';
  end if;


  select
    public.children.parent_id
  into
    v_parent_id
  from
    public.children
  where
    public.children.id =
      p_child_id;


  if v_parent_id is null then
    raise exception
      'Child not found';
  end if;


  if v_parent_id <> auth.uid() then
    raise exception
      'Not authorised';
  end if;


  -- Invalidate previous unused activation codes
  -- for this child.
  --
  -- Only the newest parent-generated code should remain useful.

  update
    public.learner_device_activations
  set
    consumed_at = now()
  where
    child_id =
      p_child_id

    and consumed_at is null

    and expires_at > now();


  -- Collision handling.
  --
  -- A six-digit namespace is deliberately small for usability,
  -- so regenerate if another active hash already exists.

  for v_attempt in 1..10 loop

    v_code :=
      private.generate_activation_code();


    v_expires_at :=
      now()
      + interval '10 minutes';


    begin

      insert into
        public.learner_device_activations (
          child_id,
          code_hash,
          expires_at
        )
      values (
        p_child_id,

        encode(
          extensions.digest(
            v_code,
            'sha256'
          ),
          'hex'
        ),

        v_expires_at
      );


      return query
      select
        v_code,
        v_expires_at;


      return;


    exception
      when unique_violation then
        null;
    end;

  end loop;


  raise exception
    'Unable to generate activation code';

end;
$$;


-- ============================================================
-- 5. REPLACE ANONYMOUS EXCHANGE FUNCTION
-- ============================================================

create or replace function
  public.exchange_learner_device_activation(
    p_activation_code text,
    p_device_name text default null
  )
returns table (
  device_id uuid,
  child_id uuid,
  device_token text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_activation
    public.learner_device_activations%rowtype;

  v_device_id uuid;

  v_device_token text;

  v_token_hash text;
begin

  perform
    private.consume_activation_attempt();


  if p_activation_code is null
    or p_activation_code
      !~ '^[0-9]{6}$'
  then
    raise exception
      'Invalid activation code';
  end if;


  if p_device_name is not null
    and char_length(
      btrim(
        p_device_name
      )
    ) not between 1 and 80
  then
    raise exception
      'Invalid device name';
  end if;


  select
    *
  into
    v_activation
  from
    public.learner_device_activations
  where
    code_hash =
      encode(
        extensions.digest(
          p_activation_code,
          'sha256'
        ),
        'hex'
      )

    and consumed_at is null

    and expires_at > now()

  order by
    created_at desc

  limit 1

  for update;


  if not found then
    raise exception
      'Invalid or expired activation code';
  end if;


  update
    public.learner_device_activations
  set
    consumed_at =
      now()
  where
    id =
      v_activation.id;


  v_device_token :=
    encode(
      extensions.gen_random_bytes(32),
      'hex'
    );


  v_token_hash :=
    encode(
      extensions.digest(
        v_device_token,
        'sha256'
      ),
      'hex'
    );


  insert into
    public.learner_devices (
      child_id,
      device_name,
      token_hash
    )
  values (
    v_activation.child_id,

    nullif(
      btrim(
        p_device_name
      ),
      ''
    ),

    v_token_hash
  )

  returning
    id
  into
    v_device_id;


  return query
  select
    v_device_id,
    v_activation.child_id,
    v_device_token;

end;
$$;


-- ============================================================
-- 6. FUNCTION PRIVILEGES
-- ============================================================

revoke all
on function
  public.create_learner_device_activation(uuid)
from public, anon;


grant execute
on function
  public.create_learner_device_activation(uuid)
to authenticated;


revoke all
on function
  public.exchange_learner_device_activation(
    text,
    text
  )
from public, authenticated;


grant execute
on function
  public.exchange_learner_device_activation(
    text,
    text
  )
to anon;


-- ============================================================
-- END
-- ============================================================
