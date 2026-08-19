-- ============================================================
-- HIBEYA Akal Budi
-- Service-role privileges for trusted backend administration
--
-- Purpose:
-- - sb_secret_* keys authenticate as service_role.
-- - service_role bypasses RLS, but still requires normal
--   PostgreSQL object privileges.
-- - These grants are for trusted server-side/admin operations
--   and automated security integration tests only.
--
-- IMPORTANT:
-- Never expose a secret/service-role key to browser code.
-- ============================================================


-- ============================================================
-- 1. APPLICATION TABLES
-- ============================================================

grant select, insert, update, delete
on table public.profiles
to service_role;


grant select, insert, update, delete
on table public.children
to service_role;


grant select, insert, update, delete
on table public.privacy_notice_versions
to service_role;


grant select, insert, update, delete
on table public.consents
to service_role;


-- ============================================================
-- 2. PUBLIC RPC
-- ============================================================

grant execute
on function public.record_consent(
  uuid,
  text,
  boolean
)
to service_role;


-- ============================================================
-- 3. PRIVATE SCHEMA
-- ============================================================
--
-- service_role may need controlled access to private
-- implementation functions for trusted backend work.
--
-- The private schema remains excluded from the exposed
-- Data API schema configuration.
-- ============================================================

grant usage
on schema private
to service_role;


grant execute
on function private.record_consent_internal(
  uuid,
  text,
  boolean
)
to service_role;


-- ============================================================
-- END
-- ============================================================
