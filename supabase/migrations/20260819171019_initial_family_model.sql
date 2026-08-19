-- ============================================================
-- HIBEYA Akal Budi
-- Initial privacy-first family model
--
-- Principles:
-- - Parent accounts authenticate; children do not.
-- - Collect minimum child data.
-- - RLS enabled from the first migration.
-- - Browser roles receive least-privilege grants.
-- - Internal trigger functions are kept outside public schema.
-- - Consent records are initially read-only from the frontend.
-- ============================================================


-- ============================================================
-- 1. INTERNAL SCHEMA
-- ============================================================

create schema if not exists private;


-- ============================================================
-- 2. PARENT PROFILES
-- ============================================================

create table public.profiles (
  id uuid primary key
    references auth.users(id)
    on delete cascade,

  display_name text
    check (
      display_name is null
      or char_length(btrim(display_name)) between 1 and 80
    ),

  preferred_language text
    not null
    default 'ms'
    check (
      preferred_language in (
        'ms',
        'en'
      )
    ),

  created_at timestamptz
    not null
    default now(),

  updated_at timestamptz
    not null
    default now()
);


-- ============================================================
-- 3. CHILD PROFILES
-- ============================================================

create table public.children (
  id uuid primary key
    default gen_random_uuid(),

  parent_id uuid
    not null
    references public.profiles(id)
    on delete cascade,

  nickname text
    not null
    check (
      char_length(btrim(nickname))
        between 1 and 40
    ),

  age_band text
    not null
    check (
      age_band in (
        '2-3',
        '3-4',
        '4-5',
        '5-6'
      )
    ),

  preferred_language text
    not null
    default 'ms'
    check (
      preferred_language in (
        'ms',
        'en'
      )
    ),

  avatar_id text
    check (
      avatar_id is null
      or char_length(btrim(avatar_id))
        between 1 and 100
    ),

  created_at timestamptz
    not null
    default now(),

  updated_at timestamptz
    not null
    default now()
);


create index children_parent_id_idx
  on public.children(parent_id);


-- ============================================================
-- 4. PRIVACY NOTICE VERSIONS
-- ============================================================

create table public.privacy_notice_versions (
  id uuid primary key
    default gen_random_uuid(),

  version text
    not null
    unique
    check (
      char_length(btrim(version))
        between 1 and 50
    ),

  effective_at timestamptz
    not null,

  notice_url text,

  created_at timestamptz
    not null
    default now()
);


create index privacy_notice_effective_at_idx
  on public.privacy_notice_versions(
    effective_at desc
  );


-- ============================================================
-- 5. CONSENT EVENT LOG
-- ============================================================

create table public.consents (
  id uuid primary key
    default gen_random_uuid(),

  parent_id uuid
    not null
    references public.profiles(id)
    on delete cascade,

  privacy_notice_version_id uuid
    not null
    references public.privacy_notice_versions(id),

  consent_type text
    not null
    check (
      char_length(btrim(consent_type))
        between 1 and 100
    ),

  granted boolean
    not null,

  recorded_at timestamptz
    not null
    default now()
);


create index consents_parent_id_idx
  on public.consents(parent_id);


create index consents_privacy_notice_version_idx
  on public.consents(
    privacy_notice_version_id
  );


create index consents_parent_type_recorded_idx
  on public.consents(
    parent_id,
    consent_type,
    recorded_at desc
  );


-- ============================================================
-- 6. ENABLE ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles
  enable row level security;

alter table public.children
  enable row level security;

alter table public.privacy_notice_versions
  enable row level security;

alter table public.consents
  enable row level security;


-- ============================================================
-- 7. LEAST-PRIVILEGE TABLE GRANTS
-- ============================================================
--
-- RLS determines WHICH rows can be accessed.
-- GRANT determines WHICH operations can be attempted.
--
-- We deliberately do not grant:
--
-- - profile INSERT
-- - profile DELETE
-- - consent INSERT
-- - consent UPDATE
-- - consent DELETE
-- - privacy notice writes
--
-- Those operations will be controlled separately.
-- ============================================================

revoke all
  on table public.profiles
  from anon, authenticated;

revoke all
  on table public.children
  from anon, authenticated;

revoke all
  on table public.privacy_notice_versions
  from anon, authenticated;

revoke all
  on table public.consents
  from anon, authenticated;


grant select, update
  on table public.profiles
  to authenticated;


grant select, insert, update, delete
  on table public.children
  to authenticated;


grant select
  on table public.privacy_notice_versions
  to anon, authenticated;


grant select
  on table public.consents
  to authenticated;


-- ============================================================
-- 8. PROFILE RLS POLICIES
-- ============================================================

create policy
  "Parents can read own profile"
on public.profiles
for select
to authenticated
using (
  id = (
    select auth.uid()
  )
);


create policy
  "Parents can update own profile"
on public.profiles
for update
to authenticated
using (
  id = (
    select auth.uid()
  )
)
with check (
  id = (
    select auth.uid()
  )
);


-- ============================================================
-- 9. CHILD RLS POLICIES
-- ============================================================

create policy
  "Parents can read own children"
on public.children
for select
to authenticated
using (
  parent_id = (
    select auth.uid()
  )
);


create policy
  "Parents can create own children"
on public.children
for insert
to authenticated
with check (
  parent_id = (
    select auth.uid()
  )
);


create policy
  "Parents can update own children"
on public.children
for update
to authenticated
using (
  parent_id = (
    select auth.uid()
  )
)
with check (
  parent_id = (
    select auth.uid()
  )
);


create policy
  "Parents can delete own children"
on public.children
for delete
to authenticated
using (
  parent_id = (
    select auth.uid()
  )
);


-- ============================================================
-- 10. PRIVACY NOTICE RLS
-- ============================================================
--
-- Privacy notices must be readable before signup/login.
--
-- No browser role receives write privileges.
-- ============================================================

create policy
  "Anyone can read privacy notices"
on public.privacy_notice_versions
for select
to anon, authenticated
using (
  true
);


-- ============================================================
-- 11. CONSENT RLS
-- ============================================================
--
-- Parents may inspect their own consent history.
--
-- Browser INSERT/UPDATE/DELETE is intentionally not allowed yet.
-- A controlled consent-recording function will be introduced
-- once the parent consent UX has been designed.
-- ============================================================

create policy
  "Parents can read own consents"
on public.consents
for select
to authenticated
using (
  parent_id = (
    select auth.uid()
  )
);


-- ============================================================
-- 12. AUTO-CREATE PROFILE AFTER AUTH SIGNUP
-- ============================================================
--
-- Supabase Auth owns auth.users.
--
-- The trigger automatically creates the corresponding
-- public profile.
--
-- SECURITY DEFINER is required because the Auth database role
-- does not normally have permission to insert into public
-- application tables.
-- ============================================================

create or replace function
  private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  insert into public.profiles (
    id,
    display_name
  )
  values (
    new.id,
    null
  );

  return new;

end;
$$;


create trigger
  on_auth_user_created
after insert
on auth.users
for each row
execute function
  private.handle_new_user();


-- ============================================================
-- 13. UPDATED-AT TRIGGER FUNCTION
-- ============================================================

create or replace function
  private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin

  new.updated_at = now();

  return new;

end;
$$;


create trigger
  profiles_set_updated_at
before update
on public.profiles
for each row
execute function
  private.set_updated_at();


create trigger
  children_set_updated_at
before update
on public.children
for each row
execute function
  private.set_updated_at();


-- ============================================================
-- END OF INITIAL FAMILY MODEL
-- ============================================================