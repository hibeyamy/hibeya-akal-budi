-- ============================================================
-- HIBEYA Akal Budi
-- Fix learner-device activation output ambiguity
--
-- PostgreSQL RETURNS TABLE output columns behave like
-- PL/pgSQL variables. The output name "expires_at" conflicted
-- with learner_device_activations.expires_at.
--
-- We avoid ambiguous output names internally and return
-- explicit aliases from the function.
-- ============================================================


drop function if exists
  public.create_learner_device_activation(uuid);


create function
  public.create_learner_device_activation(
    p_child_id uuid
  )
returns table (
  activation_code text,
  activation_expires_at timestamptz
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
    c.parent_id
  into
    v_parent_id
  from
    public.children as c
  where
    c.id = p_child_id;


  if v_parent_id is null then
    raise exception
      'Child not found';
  end if;


  if v_parent_id <> auth.uid() then
    raise exception
      'Not authorised';
  end if;


  update
    public.learner_device_activations as a
  set
    consumed_at = now()
  where
    a.child_id = p_child_id
    and a.consumed_at is null
    and a.expires_at > now();


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
        v_code::text,
        v_expires_at::timestamptz;


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


revoke all
on function
  public.create_learner_device_activation(uuid)
from public, anon;


grant execute
on function
  public.create_learner_device_activation(uuid)
to authenticated;
