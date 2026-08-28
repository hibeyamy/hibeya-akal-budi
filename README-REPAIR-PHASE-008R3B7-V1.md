# Hibeya Akal Budi — Phase 008R3B.7 Repair v1

## Why this repair exists

The first R3B.7 execution successfully:

- passed environment preflight;
- matched all six expected baseline fingerprints;
- backed up all six owned targets;
- applied all six R3B.7 final payloads;
- passed `pnpm install --frozen-lockfile`.

It then stopped before the offline test result could be evaluated because Windows PowerShell 5.1 treated native stderr from pnpm/vitest as a terminating `NativeCommandError`.

This repair does **not** reapply or overwrite the six R3B.7 source files.

It verifies that all six files still match the final R3B.7 hashes, then reruns validation with a `System.Diagnostics.Process` native runner. stdout and stderr are captured as text, and the native process `ExitCode` is the only PASS/FAIL authority.

## Run

Extract these files into the repository root:

`D:\Development\Projects\hibeya-akal-budi`

Then run either:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\repair-phase008r3b7-v1.ps1
```

or:

```cmd
run-repair-phase008r3b7-v1.cmd
```

## Validation sequence

1. Node 24 / pnpm / Git checks
2. Git status capture
3. Exact final SHA-256 verification of the six R3B.7-owned files
4. `pnpm install --frozen-lockfile`
5. `pnpm --filter @akal-budi/offline test`
6. `pnpm --filter @akal-budi/offline typecheck`
7. `pnpm --filter learner-web typecheck`
8. Targeted learner-web tests
9. `pnpm content:check`
10. Final file fingerprint verification
11. Final Git status

## Failure handling

On any genuine failure, the repair automatically creates:

`tools\dev\logs\repair-phase008r3b7-v1-<timestamp>-ERROR.zip`

The ZIP contains:

- execution log;
- evidence copy;
- failure summary.

Upload the **ERROR ZIP only** to ChatGPT.

The repair never performs `git reset`, `git clean`, checkout, stash, or automatic rollback.
