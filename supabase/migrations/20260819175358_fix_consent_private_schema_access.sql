-- ============================================================
-- HIBEYA Akal Budi
-- Fix consent RPC access to private implementation
--
-- The public RPC is SECURITY INVOKER and calls a function
-- inside the private schema.
--
-- PostgreSQL requires the calling authenticated role to have:
--   1. USAGE on the schema
--   2. EXECUTE on the function
--
-- The private schema remains unexposed through Supabase Data API.
-- ============================================================


-- ============================================================
-- 1. PRIVATE SCHEMA ACCESS
-- ============================================================

revoke all
on schema private
from public;


revoke all
on schema private
from anon;


grant usage
on schema private
to authenticated;


-- ============================================================
-- 2. INTERNAL FUNCTION PRIVILEGES
-- ============================================================

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
-- 3. PUBLIC RPC PRIVILEGES
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
-- END
-- ============================================================
