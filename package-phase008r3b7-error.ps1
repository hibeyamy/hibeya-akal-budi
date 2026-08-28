[CmdletBinding()]
param(
  [string]$RepositoryRoot = (Get-Location).Path,
  [string]$Prefix = "repair-phase008r3b7-v2"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$LogDir = Join-Path $RepoRoot "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$latestLog = Get-ChildItem -LiteralPath $LogDir -Filter "$Prefix-*.log" -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTimeUtc -Descending |
  Select-Object -First 1

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
if ($latestLog -and $latestLog.BaseName -match '^(.+)-(\d{8}-\d{9})$') {
  $stamp = $Matches[2]
}

$zipPath = Join-Path $LogDir ("{0}-{1}-ERROR.zip" -f $Prefix, $stamp)
$summaryPath = Join-Path $LogDir ("{0}-{1}-emergency-summary.txt" -f $Prefix, $stamp)
$evidencePath = Join-Path $LogDir ("{0}-{1}-evidence.txt" -f $Prefix, $stamp)

$summary = @(
  "HIBEYA AKAL BUDI - EMERGENCY ERROR BUNDLE",
  "Phase: 008R3B.7",
  "Repair: v2",
  ("Generated: {0}" -f (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")),
  ("Repository: {0}" -f $RepoRoot),
  "",
  "The primary phase/repair process returned a non-zero exit code.",
  "This ZIP was created by the independent emergency packager.",
  "Upload this ZIP to ChatGPT."
)
$summary | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$bundle = @($summaryPath)

if ($latestLog) {
  $bundle += $latestLog.FullName
  Copy-Item -LiteralPath $latestLog.FullName -Destination $evidencePath -Force
  $bundle += $evidencePath
}

$failureSummary = Get-ChildItem -LiteralPath $LogDir -Filter "$Prefix-*-failure-summary.txt" -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTimeUtc -Descending |
  Select-Object -First 1
if ($failureSummary) {
  $bundle += $failureSummary.FullName
}

$bundle = $bundle | Select-Object -Unique

if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -LiteralPath $bundle -DestinationPath $zipPath -CompressionLevel Optimal -Force

if (-not (Test-Path -LiteralPath $zipPath)) {
  throw "Emergency ZIP could not be created: $zipPath"
}

Write-Host ("ERROR ZIP: {0}" -f $zipPath)
exit 0
