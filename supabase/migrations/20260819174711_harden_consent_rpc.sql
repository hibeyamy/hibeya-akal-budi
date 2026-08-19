-- ============================================================
-- HIBEYA Akal Budi
-- Harden consent RPC architecture
--
-- Public API function:
--   SECURITY INVOKER
--
-- Privileged implementation:
--   private schema
--   SECURITY DEFINER
--
-- This keeps privileged database logic outside the exposed
-- public API schema.
-- ============================================================


-- ============================================================
-- 1. REMOVE EXISTING PUBLIC SECURITY-DEFINER FUNCTION
-- ============================================================

drop function if exists
  public.record_consent(
    uuid,
    text,
    boolean
  );


-- ============================================================
-- 2. PRIVATE PRIVILEGED IMPLEMENTATION
-- ============================================================

create or replace function
  private.record_consent_internal(
    p_privacy_notice_version_id uuid,
    p_consent_type text,
    p_granted boolean
  )
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parent_id uuid;
  v_consent_id uuid;
begin

  v_parent_id :=
    auth.uid();

  if v_parent_id is null then
    raise exception
      'Authentication required';
  end if;


  if p_consent_type not in (
    'privacy-notice',
    'essential-data-processing',
    'product-analytics',
    'research-participation',
    'marketing'
  ) then
    raise exception
      'Unsupported consent type';
  end if;


  if not exists (
    select 1
    from public.privacy_notice_versions
    where id =
      p_privacy_notice_version_id
  ) then
    raise exception
      'Unknown privacy notice version';
  end if;


  insert into public.consents (
    parent_id,
    privacy_notice_version_id,
    consent_type,
    granted
  )
  values (
    v_parent_id,
    p_privacy_notice_version_id,
    p_consent_type,
    p_granted
  )
  returning id
  into v_consent_id;


  return v_consent_id;

end;
$$;


revoke all
on function private.record_consent_internal(
  uuid,
  text,
  boolean
)
from public;


revoke all
on function private.record_consent_internal(
  uuid,
  text,
  boolean
)
from anon;


grant execute
on function private.record_consent_internal(
  uuid,
  text,
  boolean
)
to authenticated;


-- ============================================================
-- 3. PUBLIC RPC WRAPPER
-- ============================================================

create or replace function
  public.record_consent(
    p_privacy_notice_version_id uuid,
    p_consent_type text,
    p_granted boolean
  )
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select private.record_consent_internal(
    p_privacy_notice_version_id,
    p_consent_type,
    p_granted
  );
$$;


revoke all
on function public.record_consent(
  uuid,
  text,
  boolean
)
from public;


revoke all
on function public.record_consent(
  uuid,
  text,
  boolean
)
from anon;


grant execute
on function public.record_consent(
  uuid,
  text,
  boolean
)
to authenticated;


-- ============================================================
-- END
-- ============================================================
