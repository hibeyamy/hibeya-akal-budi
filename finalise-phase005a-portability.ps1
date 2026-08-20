param(
  [switch]$SkipPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$tempRoot = Join-Path $env:TEMP "hibeya-akal-budi-portability"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )

  [System.IO.File]::WriteAllText(
    $Path,
    $Content.TrimEnd() + "`n",
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Invoke-Native {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command,
    [string]$WorkingDirectory = $repoRoot
  )

  Write-Step $Name

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logsRoot "portability-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "portability-$timestamp-err.log"

  $process = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d", "/s", "/c", $Command) `
    -WorkingDirectory $WorkingDirectory `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -NoNewWindow `
    -Wait `
    -PassThru

  $outText = if (Test-Path $stdout) { Get-Content $stdout -Raw } else { "" }
  $errText = if (Test-Path $stderr) { Get-Content $stderr -Raw } else { "" }

  if ($outText) { Write-Host $outText }
  if ($errText) { Write-Host $errText }

  if ($process.ExitCode -ne 0) {
    $diagnostic = Join-Path $logsRoot "FAILED-portability-$timestamp-$($Name.Replace(' ','-')).log"

    Write-Utf8NoBom `
      -Path $diagnostic `
      -Content @"
COMMAND:
$Command

WORKING DIRECTORY:
$WorkingDirectory

EXIT CODE:
$($process.ExitCode)

STDOUT:
$outText

STDERR:
$errText
"@

    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diagnostic"
  }

  Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 005A FINALISATION" -ForegroundColor Cyan
Write-Host "Commit, push & fresh-clone portability verification" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# Preflight
# ------------------------------------------------------------

Invoke-Native `
  -Name "Project doctor" `
  -Command "node tools\dev\doctor.mjs"

Invoke-Native `
  -Name "Content compiler check" `
  -Command "node tools\content-compiler\compile.mjs --check"

Invoke-Native `
  -Name "Typecheck" `
  -Command "pnpm typecheck"

Invoke-Native `
  -Name "All tests" `
  -Command "pnpm test"

Invoke-Native `
  -Name "Production build" `
  -Command "pnpm build"

Invoke-Native `
  -Name "Git whitespace check" `
  -Command "git diff --check"

# ------------------------------------------------------------
# Ensure we have an origin remote
# ------------------------------------------------------------

Write-Step "Resolving Git origin"

$origin =
  (
    git remote get-url origin
  ).Trim()

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($origin)) {
  throw "Git origin remote is not configured."
}

Write-Host "Origin: $origin" -ForegroundColor Green

# ------------------------------------------------------------
# Commit current portability checkpoint if needed
# ------------------------------------------------------------

Write-Step "Checking working tree"

$status =
  git status --porcelain

if ($status) {
  Write-Host "Uncommitted changes detected. Creating validated checkpoint..." -ForegroundColor Yellow

  Invoke-Native `
    -Name "Git stage" `
    -Command "git add ."

  Invoke-Native `
    -Name "Git commit" `
    -Command 'git commit -m "chore: complete phase 005 content automation and portability"'
}
else {
  Write-Host "Working tree already clean." -ForegroundColor Green
}

if (-not $SkipPush) {
  Invoke-Native `
    -Name "Git push" `
    -Command "git push"
}
else {
  Write-Host ""
  Write-Host "Push skipped by request." -ForegroundColor Yellow
}

# ------------------------------------------------------------
# Fresh clone
# ------------------------------------------------------------

Write-Step "Preparing clean verification directory"

if (Test-Path $tempRoot) {
  Remove-Item $tempRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$cloneDir =
  Join-Path $tempRoot "hibeya-akal-budi"

Invoke-Native `
  -Name "Fresh Git clone" `
  -Command ('git clone "' + $origin + '" "' + $cloneDir + '"') `
  -WorkingDirectory $tempRoot

# ------------------------------------------------------------
# Verify fresh clone contains no local secrets
# ------------------------------------------------------------

Write-Step "Checking fresh clone for local secret files"

$secretCandidates = @(
  ".env",
  ".env.local",
  ".env.security.local"
)

foreach ($relative in $secretCandidates) {
  $candidate = Join-Path $cloneDir $relative

  if (Test-Path $candidate) {
    throw "Fresh clone unexpectedly contains local secret file: $relative"
  }
}

Write-Host "No local secret files present in fresh clone." -ForegroundColor Green

# ------------------------------------------------------------
# Fresh clone toolchain + dependency/bootstrap checks
# ------------------------------------------------------------

Invoke-Native `
  -Name "Fresh clone project doctor" `
  -Command "node tools\dev\doctor.mjs" `
  -WorkingDirectory $cloneDir

Invoke-Native `
  -Name "Fresh clone dependency install" `
  -Command "pnpm install --frozen-lockfile" `
  -WorkingDirectory $cloneDir

Invoke-Native `
  -Name "Fresh clone content compiler check" `
  -Command "node tools\content-compiler\compile.mjs --check" `
  -WorkingDirectory $cloneDir

Invoke-Native `
  -Name "Fresh clone typecheck" `
  -Command "pnpm typecheck" `
  -WorkingDirectory $cloneDir

Invoke-Native `
  -Name "Fresh clone tests" `
  -Command "pnpm test" `
  -WorkingDirectory $cloneDir

Invoke-Native `
  -Name "Fresh clone production build" `
  -Command "pnpm build" `
  -WorkingDirectory $cloneDir

Invoke-Native `
  -Name "Fresh clone Git whitespace check" `
  -Command "git diff --check" `
  -WorkingDirectory $cloneDir

# Ensure compiler/build did not mutate source-controlled files.
Write-Step "Checking fresh clone source determinism"

$cloneStatus =
  git -C $cloneDir status --porcelain

if ($cloneStatus) {
  Write-Host $cloneStatus
  throw "Fresh clone validation changed tracked/untracked repository files unexpectedly."
}

Write-Host "Fresh clone remained clean after validation." -ForegroundColor Green

# ------------------------------------------------------------
# Record portability verification marker locally
# ------------------------------------------------------------

$reportPath =
  Join-Path $repoRoot "tools\dev\PORTABILITY_VERIFIED.md"

$branch =
  (
    git branch --show-current
  ).Trim()

$commit =
  (
    git rev-parse HEAD
  ).Trim()

$verifiedAt =
  Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"

$report = @"
# Portability Verification

Status: **PASS**

Verified at: $verifiedAt  
Branch: $branch  
Commit: $commit

The project was cloned from the configured Git origin into a clean temporary directory and successfully completed:

- project doctor
- frozen-lockfile dependency installation
- manifest compiler reproducibility check
- TypeScript typecheck
- automated tests
- production build
- Git whitespace validation
- clean working-tree verification after build/test

Local environment secret files were not present in the fresh clone.

This verifies source/toolchain portability. Environment-specific credentials remain intentionally external to Git.
"@

Write-Utf8NoBom `
  -Path $reportPath `
  -Content $report

Invoke-Native `
  -Name "Commit portability verification report" `
  -Command 'git add tools/dev/PORTABILITY_VERIFIED.md && git commit -m "chore: record fresh-clone portability verification"'

if (-not $SkipPush) {
  Invoke-Native `
    -Name "Push portability verification report" `
    -Command "git push"
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 005A: PORTABILITY VERIFIED" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "The project is now ready to continue development from another machine." -ForegroundColor Green
Write-Host "Next architecture phase: 005B Curriculum & Skill Architecture." -ForegroundColor Cyan
