# Hibeya Akal Budi — Phase 008R3B.7 Repair v2

## Root cause fixed

Repair v1 stopped immediately after printing:

`COMMAND: pnpm install --frozen-lockfile`

The R3B.7 source hashes were correct. The issue was the v1 native process wrapper.

Repair v2 removes asynchronous stdout/stderr pipe handlers entirely.

Every native validation command now uses:

- `Start-Process`
- stdout redirected directly to a temporary file
- stderr redirected directly to a temporary file
- `-Wait -PassThru`
- the actual process `ExitCode` as the only success/failure authority

This avoids:

1. Windows PowerShell 5.1 `NativeCommandError` promotion; and
2. asynchronous pipe deadlock/hang risks.

## Guaranteed error ZIP fallback

There are now **two independent error packaging layers**:

1. the main repair script attempts to create the error ZIP;
2. if the main script exits non-zero for any reason, the CMD wrapper invokes
   `package-phase008r3b7-error.ps1` independently.

Therefore, even if the main script's catch/error-packaging path itself fails,
the wrapper still attempts to generate:

`tools\dev\logs\repair-phase008r3b7-v2-<timestamp>-ERROR.zip`

## Execute

Extract all files into:

`D:\Development\Projects\hibeya-akal-budi`

Run:

```powershell
.\run-repair-phase008r3b7-v2.cmd
```

This CMD entry point is now the recommended execution method because it provides the independent ERROR-ZIP fallback.

## On failure

Upload only:

`tools\dev\logs\repair-phase008r3b7-v2-<timestamp>-ERROR.zip`

## On success

Upload:

`tools\dev\logs\repair-phase008r3b7-v2-<timestamp>-evidence.txt`

No R3B.7 source files are overwritten by this repair. Their expected final hashes are verified before validation.
