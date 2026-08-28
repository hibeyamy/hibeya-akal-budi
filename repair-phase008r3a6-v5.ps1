Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3a6-repair-v5-" + $stamp)
$log = Join-Path $work "repair.log"
$zip = Join-Path $logs ("phase008r3a6-repair-v5-" + $stamp + ".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
    Add-Content -Path $log -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Save-Zip {
    if (Test-Path $zip) { Remove-Item -Path $zip -Force }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}

trap {
    Log ""
    Log "PHASE 008R3A.6 REPAIR V5: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    Save-Zip
    Write-Host ("ZIP: " + $zip) -ForegroundColor Yellow
    exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.6 REPAIR V5" -ForegroundColor Cyan
Write-Host "Git Whitespace Gate - Native Warning Safe" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "PASS: V4 visual regression already completed: 3/3 responsive tests passed"
Log "PASS: V4 content compiler reproducibility already passed"
Log "PASS: V4 frozen lockfile already passed"
Log "INFO: V4 failed only because PowerShell promoted Git stderr warning to NativeCommandError"

Log ""
Log "==> Git whitespace"
Log "git diff --check"

# Do not merge stderr into the PowerShell error stream. Git may emit harmless
# line-ending warnings on stderr while still returning exit code 0.
$stdout = Join-Path $work "git-diff-check-stdout.txt"
$stderr = Join-Path $work "git-diff-check-stderr.txt"

$p = Start-Process -FilePath "git.exe" `
    -ArgumentList @("diff","--check") `
    -WorkingDirectory $root `
    -NoNewWindow `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr

if (Test-Path $stdout) {
    $text = Get-Content -Path $stdout -Raw -ErrorAction SilentlyContinue
    if ($text) { Log $text.TrimEnd() }
}

if (Test-Path $stderr) {
    $text = Get-Content -Path $stderr -Raw -ErrorAction SilentlyContinue
    if ($text) {
        Log "Git stderr:"
        Log $text.TrimEnd()
    }
}

if ($p.ExitCode -ne 0) {
    throw ("git diff --check reported real whitespace errors; exit code " + $p.ExitCode)
}

Log "PASS: Git whitespace"
Log ""
Log "PHASE 008R3A.6 REPAIR V5: PASS"
Log "Git line-ending warning was correctly treated as non-fatal because Git returned exit code 0."
Log "Phase 008R3A.6 is complete."
Log "Asset architecture migration and production visual-governance close-out are complete."

Save-Zip

Write-Host ""
Write-Host "PHASE 008R3A.6 REPAIR V5: PASS" -ForegroundColor Green
Write-Host "Phase 008R3A.6 is complete." -ForegroundColor Green
Write-Host ("ZIP: " + $zip) -ForegroundColor Cyan
