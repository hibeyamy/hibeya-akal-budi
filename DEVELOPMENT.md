# HIBEYA Akal Budi â€” Development Environment

## Required toolchain

- Node.js: v24.19.0
- pnpm: 11.22.0
- Git
- Supabase CLI through the project dependency / pnpm workflow

## New machine setup

1. Clone the private repository.
2. Enter the repository directory.
3. Create local environment files from .env.example.
4. Obtain actual secret values through an approved secure channel.
5. Never commit local .env files.
6. Run:

``powershell
.\bootstrap-dev.cmd
``

The bootstrap validates:

- Node version
- pnpm version
- required project files
- secret-file Git safety
- manifest compiler reproducibility
- dependency installation from the lockfile
- TypeScript
- tests
- production builds
- Supabase migration dry-run
- Git whitespace rules

## Content workflow

Create a draft manifest:

``powershell
node tools\content-compiler\new-activity.mjs activity-id
``

Compile manifests:

``powershell
node tools\content-compiler\compile.mjs
``

Verify no generated drift:

``powershell
node tools\content-compiler\compile.mjs --check
``

## Environment files

.env.example contains variable names only.

Real values belong in local ignored environment files and must never be committed.

## Portability principle

A development machine is disposable.

The reproducible source of truth consists of:

- Git repository
- lockfile
- pinned toolchain versions
- migrations
- manifests
- generated-source checks
- secure environment configuration

No commercial project knowledge should exist only on one laptop.
