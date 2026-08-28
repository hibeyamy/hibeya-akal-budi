# HIBEYA Akal Budi — Phase 008R3B.7 Persistence / Resume

## Scope

Implements the persistence/resume hardening identified by the supplied R3B.7 preflight without changing curriculum, artwork, answer keys, mastery thresholds, or progression rules.

## Changes

- Resume lookup is scoped by semantic `activityId` and exact `activityVersion`.
- Corrupt/incompatible incomplete sessions are ignored safely for resume.
- Session completion is immutable/idempotent after the first commit.
- Journey completion accepts a `sessionId` and deduplicates replay of that semantic session.
- Resume restores the original `startedAt`, preserving duration semantics across reloads.
- Choices remain disabled until persistence recovery inspection completes.
- A recovery prompt blocks hidden creation of a second session.
- Concurrent/double taps are serialised at the player boundary.
- `Mula semula` deletes the abandoned incomplete session.
- Sync queue now returns only structurally valid completed sessions; incomplete attempts are never sent to remote progress sync.
- Generic persistence paths cover `beza-bunga-raya-001` using the same contract as other enabled activities.

## Tests added

- Activity-scoped resume selection.
- Exact content-version compatibility for resume.
- Immutable completion replay.
- Session-aware journey idempotency.
- Incomplete sessions excluded from sync queue.
- Abandoned session deletion.

## Verification performed in this environment

- TypeScript parser pass was executed against all changed TypeScript/TSX files. No syntax diagnostics were produced.
- Full repository tests could not be executed here because the supplied archive is a preflight/source subset and does not include the repository dependency installation/workspace layout; the available runtime is also Node 22 while the project declares Node >=24 <25.

## Recommended repository validation

Run in the actual repository with Node 24 and pnpm 11.22.0:

```bash
pnpm --filter @akal-budi/offline test
pnpm --filter learner-web typecheck
pnpm --filter learner-web test
pnpm test:run
pnpm content:check
pnpm content:eligibility:validate
pnpm content:sequence:validate
pnpm mastery:validate
```
