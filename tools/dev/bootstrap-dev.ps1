param(
  [switch]$SkipInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot =
  (
    Resolve-Path (
      Join-Path `
        $PSScriptRoot `
        "..\.."
    )
  ).Path

Set-Location $repoRoot

Write-Host ""
Write-Host "HIBEYA AKAL BUDI - DEV BOOTSTRAP" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

if (
  -not (
    Get-Command node -ErrorAction SilentlyContinue
  )
) {
  throw "Node.js is not installed."
}

if (
  -not (
    Get-Command pnpm -ErrorAction SilentlyContinue
  )
) {
  throw "pnpm is not available. Install/enable Corepack and the pinned pnpm version first."
}

node tools/dev/doctor.mjs

if ($LASTEXITCODE -ne 0) {
  throw "Project doctor failed before dependency installation."
}

if (
  -not $SkipInstall
) {
  Write-Host ""
  Write-Host "Installing dependencies from lockfile..." -ForegroundColor Cyan

  pnpm install --frozen-lockfile

  if ($LASTEXITCODE -ne 0) {
    throw "pnpm install failed."
  }
}

Write-Host ""
Write-Host "Running validation..." -ForegroundColor Cyan

pnpm typecheck
if ($LASTEXITCODE -ne 0) {
  throw "Typecheck failed."
}

pnpm test
if ($LASTEXITCODE -ne 0) {
  throw "Tests failed."
}

pnpm build
if ($LASTEXITCODE -ne 0) {
  throw "Build failed."
}

node tools/content-compiler/compile.mjs --check
if ($LASTEXITCODE -ne 0) {
  throw "Content compiler check failed."
}

pnpm supabase db push --dry-run
if ($LASTEXITCODE -ne 0) {
  throw "Supabase migration dry-run failed."
}

git diff --check
if ($LASTEXITCODE -ne 0) {
  throw "Git whitespace validation failed."
}

Write-Host ""
Write-Host "BOOTSTRAP VALIDATION: PASS" -ForegroundColor Green
