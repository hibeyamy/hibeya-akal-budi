# Hibeya Akal Budi — Phase 008R3B.7 PowerShell Handoff

## Purpose

Implements the persistence/resume hardening approved by the Phase 008R3B.7 preflight, using the project's normal PowerShell + evidence workflow.

## Run location

Extract these files into the Hibeya Akal Budi repository root, normally:

`D:\Development\Projects\hibeya-akal-budi`

## Recommended execution

From **Windows PowerShell 5.1** opened in the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\phase008r3b7-persistence-resume.ps1
```

Equivalent wrapper:

```powershell
.\run-phase008r3b7.cmd
```

Optional non-mutating fingerprint/toolchain check:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\phase008r3b7-persistence-resume.ps1 -PreflightOnly
```

## Safety behaviour

- Requires Node 24.x.
- Does **not** require a clean Git working tree.
- Fingerprints each of the six phase-owned files before mutation.
- Refuses to overwrite a target that differs from both the captured preflight version and intended R3B.7 version.
- Creates timestamped backups under `tools\dev\backups\`.
- Does not reset, stash, checkout, clean, or automatically roll back the repository.
- Re-running is safe when the six targets already match the intended final hashes.

## Validation gates

1. `pnpm install --frozen-lockfile`
2. `pnpm --filter @akal-budi/offline test`
3. `pnpm --filter @akal-budi/offline typecheck`
4. `pnpm --filter learner-web typecheck`
5. Targeted learner journey tests
6. `pnpm content:check`
7. Final SHA-256 verification of all six phase-owned targets
8. Final Git status capture

Any failed gate terminates with exit code 1.

## Logs and evidence

Generated automatically in:

`tools\dev\logs\phase008r3b7-persistence-resume-<timestamp>.log`

`tools\dev\logs\phase008r3b7-persistence-resume-<timestamp>-evidence.txt`

The evidence file mirrors the completed execution log for easy return to ChatGPT.

## PASS criterion

The run is complete only when the log ends with:

`PHASE 008R3B.7: PASS`

If it fails, return the generated `.log` or `-evidence.txt` file without manually editing the repository first.
