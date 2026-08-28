Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008l-repair-v1-$runId.log"

$learnerPackagePath = Join-Path $root "apps\learner-web\package.json"
$lockfilePath = Join-Path $root "pnpm-lock.yaml"
$phaseScriptPath = Join-Path $root "phase008l-skill-mastery.ps1"

function WriteText([string]$Path,[string]$Content) {
    $dir = Split-Path -Parent $Path

    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    [IO.File]::WriteAllText(
        $Path,
        $Content.TrimEnd() + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Backup([string]$Path) {
    if (-not (Test-Path $Path)) {
        return
    }

    $relative = $Path.Substring($root.Length).TrimStart("\")
    $safe = $relative -replace '[\\/:*?"<>|]', '_'

    Copy-Item `
        $Path `
        (Join-Path $backups "$runId-$safe") `
        -Force
}

function Run([string]$Name,[string]$Command) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

    $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $out = Join-Path $logs "phase008l-repair-v1-$stamp-out.log"
    $err = Join-Path $logs "phase008l-repair-v1-$stamp-err.log"

    $p = Start-Process `
        -FilePath "cmd.exe" `
        -ArgumentList @("/d","/s","/c",$Command) `
        -WorkingDirectory $root `
        -RedirectStandardOutput $out `
        -RedirectStandardError $err `
        -NoNewWindow `
        -Wait `
        -PassThru

    $stdout = if (Test-Path $out) { Get-Content $out -Raw } else { "" }
    $stderr = if (Test-Path $err) { Get-Content $err -Raw } else { "" }

    if ($stdout) {
        Write-Host $stdout
        Add-Content $log $stdout -Encoding UTF8
    }

    if ($stderr) {
        Write-Host $stderr
        Add-Content $log $stderr -Encoding UTF8
    }

    if ($p.ExitCode -ne 0) {
        $diag = Join-Path $logs "FAILED-phase008l-repair-v1-$stamp-$($Name.Replace(' ','-')).log"

        WriteText `
            $diag `
            "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

        throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
    }

    Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
    Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
    Add-Content `
        $log `
        "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" `
        -Encoding UTF8

    Write-Host ""
    Write-Host "PHASE 008L REPAIR V1: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    Write-Host "Do not make manual source edits unless explicitly requested after log review." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008L REPAIR V1" -ForegroundColor Cyan
Write-Host "Lockfile Reconciliation + Validation Resume" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# 1. Confirm this is the exact partial Phase 008L state.
# ------------------------------------------------------------------

foreach ($required in @(
    $learnerPackagePath,
    $lockfilePath,
    (Join-Path $root "packages\learning-insights\src\mastery.ts"),
    (Join-Path $root "packages\offline\src\skillMastery.repository.ts"),
    (Join-Path $root "apps\learner-web\src\services\skillMasteryService.ts"),
    (Join-Path $root "packages\content-library\src\eligibility.ts"),
    (Join-Path $root "tools\content-compiler\compile.mjs"),
    (Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx")
)) {
    if (-not (Test-Path $required)) {
        throw "Expected partial Phase 008L file is missing: $required"
    }
}

$learnerPackage = Get-Content $learnerPackagePath -Raw | ConvertFrom-Json

if (
    $null -eq $learnerPackage.dependencies -or
    $learnerPackage.dependencies.'@akal-budi/learning-insights' -ne "workspace:*"
) {
    throw "apps/learner-web/package.json does not contain the expected Phase 008L workspace dependency."
}

$mastery = Get-Content (Join-Path $root "packages\learning-insights\src\mastery.ts") -Raw
$eligibility = Get-Content (Join-Path $root "packages\content-library\src\eligibility.ts") -Raw
$player = Get-Content (Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx") -Raw

foreach ($token in @(
    "applySkillMasteryEvidence",
    "processedSessionIds",
    "getMasteredSkillIds"
)) {
    if ($mastery -notmatch [Regex]::Escape($token)) {
        throw "Partial Phase 008L mastery contract is incomplete. Missing token: $token"
    }
}

foreach ($token in @(
    "masteredSkillIds",
    "getEligibleActivitiesForLearner"
)) {
    if ($eligibility -notmatch [Regex]::Escape($token)) {
        throw "Partial Phase 008L eligibility contract is incomplete. Missing token: $token"
    }
}

foreach ($token in @(
    "recordSessionSkillMastery",
    "catalogue.skillMappings",
    "recordCompletedJourneyActivity"
)) {
    if ($player -notmatch [Regex]::Escape($token)) {
        throw "Partial Phase 008L ActivityPlayer integration is incomplete. Missing token: $token"
    }
}

Write-Host "PASS: exact partial Phase 008L state verified" -ForegroundColor Green
Write-Host "PASS: failure is isolated to lockfile reconciliation" -ForegroundColor Green

# ------------------------------------------------------------------
# 2. Back up lockfile before package-manager reconciliation.
# ------------------------------------------------------------------

Backup $lockfilePath
Backup $phaseScriptPath

# ------------------------------------------------------------------
# 3. Correct the original Phase 008L script for future reproducibility.
#    This does NOT rerun the migration.
# ------------------------------------------------------------------

if (Test-Path $phaseScriptPath) {
    $phaseScript = Get-Content $phaseScriptPath -Raw

    $oldLine = 'Run "Install workspace links with frozen lockfile" "pnpm install --frozen-lockfile"'

    if ($phaseScript.Contains($oldLine)) {
        $replacement = @'
Run "Reconcile lockfile for newly declared workspace dependency" "pnpm install --lockfile-only --no-frozen-lockfile"
Run "Verify frozen lockfile and workspace links" "pnpm install --frozen-lockfile"
'@

        $phaseScript = $phaseScript.Replace(
            $oldLine,
            $replacement.TrimEnd()
        )

        WriteText $phaseScriptPath $phaseScript

        Write-Host "PASS: original Phase 008L install stage corrected for future reproducibility" -ForegroundColor Green
    }
    else {
        Write-Host "INFO: original Phase 008L install stage was already corrected or differs; no patch applied." -ForegroundColor DarkYellow
    }
}

# ------------------------------------------------------------------
# 4. Reconcile lockfile deliberately.
#
# The failure occurred because package.json changed before a frozen-lockfile
# install. The correct sequence is:
#   a) package manager updates lockfile only
#   b) frozen install verifies lockfile/package.json agreement
#
# No arbitrary package upgrade is requested.
# ------------------------------------------------------------------

Run `
    "Reconcile lockfile for Phase 008L workspace dependency" `
    "pnpm install --lockfile-only --no-frozen-lockfile"

# Hard postcondition: the lockfile must now accept frozen mode.
Run `
    "Verify frozen lockfile and workspace links" `
    "pnpm install --frozen-lockfile"

Write-Host "PASS: pnpm-lock.yaml now matches apps/learner-web/package.json" -ForegroundColor Green
Write-Host "PASS: workspace dependency linking verified under frozen-lockfile mode" -ForegroundColor Green

# ------------------------------------------------------------------
# 5. Resume Phase 008L from the exact point after the failed install.
# ------------------------------------------------------------------

Run `
    "Compile mastery-aware content catalogue" `
    "node tools/content-compiler/compile.mjs"

Run `
    "Content compiler reproducibility" `
    "pnpm content:check"

$cataloguePath = Join-Path $root "packages\content-library\src\catalogue.ts"

if (-not (Test-Path $cataloguePath)) {
    throw "Generated catalogue missing after Phase 008L compilation."
}

$catalogue = Get-Content $cataloguePath -Raw

foreach ($token in @(
    "skillMappings:",
    "requiredPrerequisiteSkillIds:"
)) {
    if ($catalogue -notmatch [Regex]::Escape($token)) {
        throw "Generated mastery catalogue postcondition failed. Missing token: $token"
    }
}

Write-Host "PASS: generated catalogue exposes weighted skill mappings" -ForegroundColor Green

Run `
    "Learning insights mastery tests" `
    "pnpm --filter @akal-budi/learning-insights test"

Run `
    "Offline mastery persistence tests" `
    "pnpm --filter @akal-budi/offline test"

Run `
    "Content library eligibility tests" `
    "pnpm --filter @akal-budi/content-library test"

Run `
    "Learner selector tests" `
    "pnpm --filter learner-web exec vitest run src/features/play/selectLearnerActivity.test.ts"

Run `
    "Learning insights typecheck" `
    "pnpm --filter @akal-budi/learning-insights typecheck"

Run `
    "Offline package typecheck" `
    "pnpm --filter @akal-budi/offline typecheck"

Run `
    "Content library typecheck" `
    "pnpm --filter @akal-budi/content-library typecheck"

Run `
    "Learner web typecheck" `
    "pnpm --filter learner-web typecheck"

Run `
    "Learner web tests" `
    "pnpm --filter learner-web test"

Run `
    "Content sequencing validation" `
    "pnpm content:sequence:validate"

Run `
    "Content eligibility validation" `
    "pnpm content:eligibility:validate"

Run `
    "Curriculum validation" `
    "pnpm curriculum:validate"

Run `
    "Repository typecheck" `
    "pnpm typecheck"

Run `
    "All tests" `
    "pnpm test"

Run `
    "Production build" `
    "pnpm build"

# Storybook is rebuilt immediately before browser QA so stale static output
# cannot contaminate the E2E results.
Run `
    "Storybook production build" `
    "pnpm storybook:build"

Run `
    "Learner journey regression" `
    "pnpm qa:journey"

Run `
    "Accessibility regression" `
    "pnpm qa:a11y"

Run `
    "Visual regression" `
    "pnpm qa:visual"

Run `
    "Git whitespace check" `
    "git diff --check"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008L REPAIR V1: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "pnpm-lock.yaml is reconciled with the new workspace dependency." -ForegroundColor Cyan
Write-Host "Phase 008L validation resumed from the failed install boundary." -ForegroundColor Cyan
Write-Host "No source rollback or manual intervention was required." -ForegroundColor Cyan
