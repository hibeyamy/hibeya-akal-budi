create or replace function
  public.get_learner_runtime_profile(
    p_device_id uuid,
    p_device_token text
  )
returns table (
  child_id uuid,
  age_band text,
  preferred_language text
)
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

  return query
  select
    c.id,
    c.age_band,
    c.preferred_language
  from
    public.children as c
  where
    c.id =
      v_device.child_id;

end;
$$;


revoke all
on function
  public.get_learner_runtime_profile(
    uuid,
    text
  )
from public, authenticated;


grant execute
on function
  public.get_learner_runtime_profile(
    uuid,
    text
  )
to anon;