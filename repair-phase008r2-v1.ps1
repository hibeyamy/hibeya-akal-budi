Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$workDir = Join-Path $logs "phase008r2-repair-v1-$stamp"
$rawLog = Join-Path $workDir "repair.log"
$zipLog = Join-Path $logs "phase008r2-repair-v1-$stamp.zip"

New-Item -ItemType Directory -Force -Path $workDir | Out-Null

$phaseScript = Join-Path $root "phase008r2-first-governed-content-pack.ps1"
$compiler = Join-Path $root "tools\content-compiler\compile.mjs"
$manifest = Join-Path $root "content\activity-manifests\beza-bunga-raya-001.json"
$packageJson = Join-Path $root "package.json"

function Log([string]$Text = "") {
    Add-Content -Path $rawLog -Value $Text -Encoding UTF8
}

function Backup([string]$Path) {
    if (-not (Test-Path $Path)) { return }

    $relative = $Path.Substring($root.Length).TrimStart("\")
    $safe = $relative -replace '[\\/:*?"<>|]', '_'

    Copy-Item `
        $Path `
        (Join-Path $backups "$stamp-$safe") `
        -Force
}

function Zip-Logs {
    if (Test-Path $zipLog) {
        Remove-Item $zipLog -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $workDir) {
        Compress-Archive `
            -Path (Join-Path $workDir "*") `
            -DestinationPath $zipLog `
            -Force
    }
}

function Native([string]$Name,[string]$Command) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Write-Host $Command

    Log ""
    Log "==> $Name"
    Log $Command

    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = & "$env:ComSpec" /d /c $Command 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $old
    }

    foreach ($item in $output) {
        $text =
            if ($item -is [System.Management.Automation.ErrorRecord]) {
                $item.Exception.Message
            }
            else {
                [string]$item
            }

        Write-Host $text
        Log $text
    }

    Log "EXIT CODE: $code"

    if ($code -ne 0) {
        throw "$Name failed with exit code $code"
    }

    Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
    Log ""
    Log "PHASE 008R2 REPAIR V1: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace

    Zip-Logs

    Write-Host ""
    Write-Host "PHASE 008R2 REPAIR V1: FAILED" -ForegroundColor Red
    Write-Host "Diagnostic ZIP: $zipLog" -ForegroundColor Yellow
    Write-Host "Raw repair log is stored only inside the ZIP." -ForegroundColor Yellow

    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R2 REPAIR V1" -ForegroundColor Cyan
Write-Host "Compiler Command + Zipped Log Repair" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "HIBEYA AKAL BUDI - PHASE 008R2 REPAIR V1"
Log "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"

# ------------------------------------------------------------------
# 1. Diagnose the exact failure state before modifying anything.
# ------------------------------------------------------------------

foreach ($required in @(
    $compiler,
    $manifest,
    $packageJson
)) {
    if (-not (Test-Path $required)) {
        throw "Expected partial Phase 008R2 state missing: $required"
    }
}

$package = Get-Content $packageJson -Raw
$compilerText = Get-Content $compiler -Raw
$manifestText = Get-Content $manifest -Raw

if ($package -match '"content:compile"') {
    Write-Host "INFO: package.json now contains content:compile; direct compiler invocation will still be used." -ForegroundColor DarkYellow
}
else {
    Write-Host "PASS: confirmed package.json has no content:compile script" -ForegroundColor Green
}

foreach ($token in @(
    "isSafeDraftManifest",
    "validateDraftManifest",
    "DRAFT SKIPPED:"
)) {
    if ($compilerText -notmatch [Regex]::Escape($token)) {
        throw "Partial 008R2 compiler patch is incomplete. Missing token: $token"
    }
}

foreach ($token in @(
    '"id": "beza-bunga-raya-001"',
    '"enabled": false',
    '"active": false',
    '"originalityReviewed": false',
    '"skillId": "visual-discrimination"',
    '"role": "primary"'
)) {
    if ($manifestText -notmatch [Regex]::Escape($token)) {
        throw "Partial 008R2 draft contract is incomplete. Missing token: $token"
    }
}

Write-Host "PASS: exact partial Phase 008R2 state verified" -ForegroundColor Green
Write-Host "PASS: failure isolated to invalid pnpm content:compile invocation" -ForegroundColor Green

# ------------------------------------------------------------------
# 2. Correct the original Phase 008R2 script for future reproducibility.
#    Do not rerun its migration section.
# ------------------------------------------------------------------

if (Test-Path $phaseScript) {
    Backup $phaseScript

    $source = Get-Content $phaseScript -Raw

    $oldCommand = 'Native "Compile production catalogue while skipping safe draft" "pnpm content:compile"'
    $newCommand = 'Native "Compile production catalogue while skipping safe draft" "node tools/content-compiler/compile.mjs"'

    if ($source.Contains($oldCommand)) {
        $source = $source.Replace(
            $oldCommand,
            $newCommand
        )

        [IO.File]::WriteAllText(
            $phaseScript,
            $source,
            [Text.UTF8Encoding]::new($false)
        )

        Write-Host "PASS: original Phase 008R2 compiler command corrected" -ForegroundColor Green
    }
    else {
        Write-Host "INFO: original Phase 008R2 compiler command already differs; no source patch needed." -ForegroundColor DarkYellow
    }
}

# ------------------------------------------------------------------
# 3. Resume validation from the exact failed boundary.
# ------------------------------------------------------------------

Native `
    "Compile production catalogue while skipping safe draft" `
    "node tools/content-compiler/compile.mjs"

Native `
    "Compiler reproducibility with safe draft present" `
    "pnpm content:check"

Native `
    "Content sequencing validation" `
    "pnpm content:sequence:validate"

Native `
    "Content eligibility validation" `
    "pnpm content:eligibility:validate"

Native `
    "Curriculum validation" `
    "pnpm curriculum:validate"

# Coverage is expected to FAIL because the activity is still a safe draft.
# The diagnostic must show visual-discrimination draft-primary=1.
Write-Host ""
Write-Host "==> Coverage validator draft-awareness probe" -ForegroundColor Cyan

$oldPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"

try {
    $coverageOutput = & "$env:ComSpec" /d /c "pnpm content:coverage:validate" 2>&1
    $coverageCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $oldPreference
}

$coverageText = @()

foreach ($item in $coverageOutput) {
    $text =
        if ($item -is [System.Management.Automation.ErrorRecord]) {
            $item.Exception.Message
        }
        else {
            [string]$item
        }

    $coverageText += $text
    Write-Host $text
    Log $text
}

if ($coverageCode -eq 0) {
    throw "Coverage unexpectedly passed before manual review and promotion."
}

$joinedCoverage = $coverageText -join "`n"

if (
    $joinedCoverage -notmatch "visual-discrimination" -or
    $joinedCoverage -notmatch "draft-primary=1"
) {
    throw "Coverage validator did not recognise the visual-discrimination draft as expected."
}

Write-Host "PASS: coverage validator sees draft-primary=1 without counting it as released coverage" -ForegroundColor Green

Native `
    "Repository typecheck" `
    "pnpm typecheck"

Native `
    "All tests" `
    "pnpm test"

Native `
    "Production build" `
    "pnpm build"

Native `
    "Frozen lockfile verification" `
    "pnpm install --frozen-lockfile"

Native `
    "Git whitespace check" `
    "git diff --check"

# ------------------------------------------------------------------
# 4. Finalise ZIP-only diagnostics.
# ------------------------------------------------------------------

Log ""
Log "PHASE 008R2 REPAIR V1: PASS"
Log "Compiler invocation corrected to direct Node execution."
Log "Safe draft lifecycle validated."
Log "Manual review remains required before promotion."

Zip-Logs

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008R2 REPAIR V1: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Compiler invocation is corrected." -ForegroundColor Cyan
Write-Host "Safe draft remains disabled and unreviewed." -ForegroundColor Cyan
Write-Host ""
Write-Host "MANUAL ACTION REQUIRED BEFORE 008R3:" -ForegroundColor Yellow
Write-Host "Review content\activity-manifests\beza-bunga-raya-001.json for originality, cultural suitability, age suitability, and visual clarity." -ForegroundColor Yellow
Write-Host "Do NOT toggle enabled/active/review flags manually." -ForegroundColor Yellow
Write-Host ""
Write-Host "Diagnostic ZIP: $zipLog" -ForegroundColor White

Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
