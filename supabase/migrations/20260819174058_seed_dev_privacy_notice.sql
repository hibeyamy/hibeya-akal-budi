-- ============================================================
-- HIBEYA Akal Budi
-- Development privacy notice
--
-- DEVELOPMENT DATA ONLY.
-- This is not the final production privacy notice.
-- Production wording requires dedicated legal/privacy review.
-- ============================================================

insert into public.privacy_notice_versions (
  version,
  effective_at,
  notice_url
)
values (
  'dev-1.0',
  now(),
  null
)
on conflict (version)
do nothing;
