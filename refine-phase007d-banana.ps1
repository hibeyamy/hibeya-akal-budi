Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007d-banana-refinement-$runId.log"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

function WriteText([string]$Path,[string]$Content) {
  [IO.File]::WriteAllText(
    $Path,
    $Content.TrimEnd() + "`n",
    [Text.UTF8Encoding]::new($false)
  )
}

function Backup([string]$Path) {
  if (Test-Path $Path) {
    $safe = $Path.Substring($root.Length).TrimStart("\").Replace("\","__")
    Copy-Item $Path (Join-Path $backups "$runId-$safe") -Force
  }
}

trap {
  WriteText $log @"
BANANA REFINEMENT FAILED

$($_ | Out-String)

$($_.ScriptStackTrace)
"@
  Write-Host ""
  Write-Host "BANANA REFINEMENT: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA - BANANA VISUAL REFINEMENT" -ForegroundColor Cyan
Write-Host "Phase 007D targeted correction only" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$targets = @(
  "assets\masters\banana-yellow.svg",
  "assets\exports\banana-yellow.svg",
  "packages\assets\src\generated\banana-yellow.svg"
)

foreach ($relative in $targets) {
  Backup (Join-Path $root $relative)
}

# More recognisable single-banana silhouette:
# - long crescent body
# - distinct narrow stem
# - small dark blossom tip
# - inner ridge/highlight
# - no bunch or character styling
$banana = @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 320" role="img" aria-labelledby="title desc">
  <title id="title">Yellow banana</title>
  <desc id="desc">Original HIBEYA illustration of one ripe curved yellow banana.</desc>

  <g stroke="#23333F" stroke-linecap="round" stroke-linejoin="round">
    <path
      d="M80 82
         C94 92 102 104 108 121
         C127 174 166 207 215 208
         C235 208 251 202 265 191
         C254 221 232 244 202 257
         C169 271 132 264 106 241
         C78 217 61 181 60 143
         C59 119 65 98 80 82 Z"
      fill="#F4C84A"
      stroke-width="10"
    />

    <path
      d="M80 83
         C76 72 77 60 83 49
         L98 55
         C94 66 94 76 99 87"
      fill="#D8A62E"
      stroke-width="9"
    />

    <path
      d="M83 49 L92 38"
      fill="none"
      stroke-width="9"
    />

    <path
      d="M265 191
         C273 187 278 181 282 173"
      fill="none"
      stroke-width="9"
    />

    <path
      d="M279 171 L287 168"
      fill="none"
      stroke-width="9"
    />

    <path
      d="M92 105
         C111 163 151 226 221 228"
      fill="none"
      stroke="#FFE38A"
      stroke-width="9"
    />

    <path
      d="M107 221
         C134 244 167 252 198 241"
      fill="none"
      stroke="#D6A82F"
      stroke-width="6"
      opacity="0.7"
    />
  </g>
</svg>
'@

foreach ($relative in $targets) {
  $path = Join-Path $root $relative
  $dir = Split-Path -Parent $path
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  WriteText $path $banana
}

Write-Host "PASS: banana master/export/runtime replaced" -ForegroundColor Green

& pnpm assets:first-batch:validate
if ($LASTEXITCODE -ne 0) {
  throw "First-batch validation failed."
}

Write-Host "PASS: first-batch validation" -ForegroundColor Green

& pnpm --filter @akal-budi/assets typecheck
if ($LASTEXITCODE -ne 0) {
  throw "@akal-budi/assets typecheck failed."
}

Write-Host "PASS: asset package typecheck" -ForegroundColor Green

& pnpm --filter learner-web typecheck
if ($LASTEXITCODE -ne 0) {
  throw "learner-web typecheck failed."
}

Write-Host "PASS: learner-web typecheck" -ForegroundColor Green

& git diff --check
if ($LASTEXITCODE -ne 0) {
  throw "git diff --check failed."
}

Write-Host "PASS: git diff --check" -ForegroundColor Green

WriteText $log @"
BANANA REFINEMENT: PASS
Updated only:
- assets/masters/banana-yellow.svg
- assets/exports/banana-yellow.svg
- packages/assets/src/generated/banana-yellow.svg
"@

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "BANANA REFINEMENT: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Manual review required:" -ForegroundColor Cyan
Write-Host "  pnpm storybook" -ForegroundColor White
Write-Host "Then open Assets -> First Original Batch -> Review Gallery" -ForegroundColor White
