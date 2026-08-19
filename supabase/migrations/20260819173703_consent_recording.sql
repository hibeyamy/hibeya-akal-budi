-- ============================================================
-- HIBEYA Akal Budi
-- Controlled parent consent recording
--
-- Design:
-- - Consent history is append-only.
-- - Parents cannot directly INSERT/UPDATE/DELETE consent rows.
-- - Consent is recorded through a controlled RPC.
-- - Withdrawal creates another event rather than rewriting history.
-- ============================================================


-- ============================================================
-- 1. CONSENT TYPE CONSTRAINT
-- ============================================================
--
-- This constraint may already exist from an earlier schema
-- migration. Drop and recreate it so this migration is safe
-- against the current development database state.
-- ============================================================

alter table public.consents
drop constraint if exists
  consents_consent_type_check;

alter table public.consents
add constraint
  consents_consent_type_check
check (
  consent_type in (
    'privacy-notice',
    'essential-data-processing',
    'product-analytics',
    'research-participation',
    'marketing'
  )
);


-- ============================================================
-- 2. CONTROLLED CONSENT RECORDING FUNCTION
-- ============================================================

create or replace function
  public.record_consent(
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

  v_parent_id := auth.uid();

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


-- ============================================================
-- 3. FUNCTION ACCESS
-- ============================================================

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
-- 4. PREVENT DIRECT CONSENT MUTATION
-- ============================================================

revoke insert, update, delete
on table public.consents
from authenticated;


-- ============================================================
-- END
-- ============================================================
