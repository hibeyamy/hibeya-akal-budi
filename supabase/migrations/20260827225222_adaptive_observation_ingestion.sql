create table if not exists public.adaptive_observation_events (
  event_id uuid primary key,
  occurred_at timestamptz not null,
  authority text not null,
  fallback_reason text not null,
  rollout_bucket integer not null,
  rollout_percent numeric not null,
  legacy_activity_id text not null,
  adaptive_activity_id text null,
  selected_activity_id text not null,
  received_at timestamptz not null default now(),
  constraint adaptive_observation_authority_check check (authority in ('legacy','adaptive')),
  constraint adaptive_observation_rollout_bucket_check check (rollout_bucket between 0 and 99),
  constraint adaptive_observation_rollout_percent_check check (rollout_percent between 0 and 100),
  constraint adaptive_observation_activity_id_lengths_check check (
    char_length(legacy_activity_id) between 1 and 200
    and char_length(selected_activity_id) between 1 and 200
    and (adaptive_activity_id is null or char_length(adaptive_activity_id) between 1 and 200)
  )
);

alter table public.adaptive_observation_events enable row level security;
revoke all on table public.adaptive_observation_events from public, anon, authenticated;

create or replace function private.ingest_adaptive_observation_impl(
  p_device_id uuid,
  p_device_token text,
  p_event_id uuid,
  p_occurred_at timestamptz,
  p_authority text,
  p_fallback_reason text,
  p_rollout_bucket integer,
  p_rollout_percent numeric,
  p_legacy_activity_id text,
  p_adaptive_activity_id text,
  p_selected_activity_id text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device public.learner_devices%rowtype;
begin
  v_device := private.get_valid_learner_device(p_device_id, p_device_token);

  if p_event_id is null or p_occurred_at is null then
    raise exception 'Invalid adaptive observation identity';
  end if;

  if p_occurred_at > now() + interval '5 minutes' then
    raise exception 'Adaptive observation timestamp is in the future';
  end if;

  if p_authority not in ('legacy','adaptive')
     or p_rollout_bucket < 0 or p_rollout_bucket > 99
     or p_rollout_percent < 0 or p_rollout_percent > 100 then
    raise exception 'Invalid adaptive observation rollout fields';
  end if;

  if p_fallback_reason not in (
    'disabled','outside-cohort','legacy-null','shadow-null','shadow-error',
    'invalid-adaptive-candidate','adaptive-selected'
  ) then
    raise exception 'Invalid adaptive observation fallback reason';
  end if;

  if char_length(btrim(p_legacy_activity_id)) not between 1 and 200
     or char_length(btrim(p_selected_activity_id)) not between 1 and 200
     or (p_adaptive_activity_id is not null and char_length(btrim(p_adaptive_activity_id)) not between 1 and 200) then
    raise exception 'Invalid adaptive observation activity identifiers';
  end if;

  insert into public.adaptive_observation_events (
    event_id, occurred_at, authority, fallback_reason, rollout_bucket,
    rollout_percent, legacy_activity_id, adaptive_activity_id, selected_activity_id
  ) values (
    p_event_id, p_occurred_at, p_authority, p_fallback_reason, p_rollout_bucket,
    p_rollout_percent, btrim(p_legacy_activity_id),
    case when p_adaptive_activity_id is null then null else btrim(p_adaptive_activity_id) end,
    btrim(p_selected_activity_id)
  ) on conflict (event_id) do nothing;

  update public.learner_devices
  set last_seen_at = now()
  where id = v_device.id;

  return p_event_id;
end;
$$;

revoke execute on function private.ingest_adaptive_observation_impl(uuid,text,uuid,timestamptz,text,text,integer,numeric,text,text,text) from public, anon, authenticated;
grant usage on schema private to anon;
grant execute on function private.ingest_adaptive_observation_impl(uuid,text,uuid,timestamptz,text,text,integer,numeric,text,text,text) to anon;

create or replace function public.ingest_adaptive_observation(
  p_device_id uuid,
  p_device_token text,
  p_event_id uuid,
  p_occurred_at timestamptz,
  p_authority text,
  p_fallback_reason text,
  p_rollout_bucket integer,
  p_rollout_percent numeric,
  p_legacy_activity_id text,
  p_adaptive_activity_id text,
  p_selected_activity_id text
)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select private.ingest_adaptive_observation_impl(
    p_device_id,
    p_device_token,
    p_event_id,
    p_occurred_at,
    p_authority,
    p_fallback_reason,
    p_rollout_bucket,
    p_rollout_percent,
    p_legacy_activity_id,
    p_adaptive_activity_id,
    p_selected_activity_id
  );
$$;

revoke execute on function public.ingest_adaptive_observation(uuid,text,uuid,timestamptz,text,text,integer,numeric,text,text,text) from public, authenticated;
grant execute on function public.ingest_adaptive_observation(uuid,text,uuid,timestamptz,text,text,integer,numeric,text,text,text) to anon;
