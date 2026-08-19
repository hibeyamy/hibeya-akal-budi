-- ============================================================
-- HIBEYA Akal Budi
-- Learner device activation
--
-- Security model:
-- - Parent authenticates normally.
-- - Parent creates a short-lived activation code for own child.
-- - Learner device exchanges that code once.
-- - Raw activation codes are never stored.
-- - Learner device receives an opaque device token.
-- - Raw device tokens are never stored.
-- - Parent can revoke devices.
-- ============================================================


-- Required for secure token hashing
create extension if not exists pgcrypto;


-- ============================================================
-- 1. LEARNER DEVICES
-- ============================================================

create table public.learner_devices (
  id uuid primary key
    default gen_random_uuid(),

  child_id uuid
    not null
    references public.children(id)
    on delete cascade,

  device_name text
    check (
      device_name is null
      or char_length(btrim(device_name))
        between 1 and 80
    ),

  token_hash text
    not null
    unique,

  activated_at timestamptz
    not null
    default now(),

  last_seen_at timestamptz,

  revoked_at timestamptz,

  created_at timestamptz
    not null
    default now()
);


create index
  learner_devices_child_id_idx
on public.learner_devices(
  child_id
);


-- ============================================================
-- 2. ACTIVATION CODES
-- ============================================================

create table public.learner_device_activations (
  id uuid primary key
    default gen_random_uuid(),

  child_id uuid
    not null
    references public.children(id)
    on delete cascade,

  code_hash text
    not null
    unique,

  expires_at timestamptz
    not null,

  consumed_at timestamptz,

  created_at timestamptz
    not null
    default now(),

  check (
    expires_at > created_at
  )
);


create index
  learner_device_activations_child_id_idx
on public.learner_device_activations(
  child_id
);


create index
  learner_device_activations_expires_at_idx
on public.learner_device_activations(
  expires_at
);


-- ============================================================
-- 3. ROW LEVEL SECURITY
-- ============================================================

alter table public.learner_devices
  enable row level security;

alter table public.learner_device_activations
  enable row level security;


-- ============================================================
-- 4. PRIVILEGES
-- ============================================================

revoke all
on table public.learner_devices
from anon, authenticated;

revoke all
on table public.learner_device_activations
from anon, authenticated;


grant select
on table public.learner_devices
to authenticated;


grant select, insert, update, delete
on table public.learner_devices
to service_role;

grant select, insert, update, delete
on table public.learner_device_activations
to service_role;


-- ============================================================
-- 5. PARENT DEVICE READ POLICY
-- ============================================================

create policy
  "Parents can read own child learner devices"
on public.learner_devices
for select
to authenticated
using (
  exists (
    select 1
    from public.children
    where public.children.id =
      learner_devices.child_id
    and public.children.parent_id =
      (
        select auth.uid()
      )
  )
);


-- ============================================================
-- 6. CREATE ACTIVATION CODE
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
begin

  if auth.uid() is null then
    raise exception
      'Authentication required';
  end if;


  select
    children.parent_id
  into
    v_parent_id
  from
    public.children
  where
    children.id = p_child_id;


  if v_parent_id is null then
    raise exception
      'Child not found';
  end if;


  if v_parent_id <> auth.uid() then
    raise exception
      'Not authorised';
  end if;


  -- Six-digit human-enterable code.
  --
  -- This is intentionally short-lived and single-use.
  -- The database stores only its SHA-256 hash.

  v_code :=
    lpad(
      (
        floor(
          random() * 1000000
        )::integer
      )::text,
      6,
      '0'
    );


  v_expires_at :=
    now()
    + interval '10 minutes';


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

end;
$$;


-- ============================================================
-- 7. EXCHANGE ACTIVATION CODE
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
    consumed_at = now()
  where
    id = v_activation.id;


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
-- 8. REVOKE LEARNER DEVICE
-- ============================================================

create or replace function
  public.revoke_learner_device(
    p_device_id uuid
  )
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parent_id uuid;
begin

  if auth.uid() is null then
    raise exception
      'Authentication required';
  end if;


  select
    children.parent_id
  into
    v_parent_id
  from
    public.learner_devices

  join
    public.children
  on
    children.id =
      learner_devices.child_id

  where
    learner_devices.id =
      p_device_id;


  if v_parent_id is null then
    raise exception
      'Device not found';
  end if;


  if v_parent_id <> auth.uid() then
    raise exception
      'Not authorised';
  end if;


  update
    public.learner_devices
  set
    revoked_at = now()
  where
    id = p_device_id
    and revoked_at is null;

end;
$$;


-- ============================================================
-- 9. FUNCTION PRIVILEGES
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


revoke all
on function
  public.revoke_learner_device(uuid)
from public, anon;

grant execute
on function
  public.revoke_learner_device(uuid)
to authenticated;


-- ============================================================
-- END
-- ============================================================
