param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$target = Join-Path $root "repair-phase008f-v6.ps1"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008f-repair-v9-$runId.log"

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

trap {
    Add-Content `
        $log `
        "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" `
        -Encoding UTF8

    Write-Host ""
    Write-Host "PHASE 008F REPAIR V9: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow

    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008F REPAIR V9" -ForegroundColor Cyan
Write-Host "Repair partially-patched V6 safely and idempotently" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $target)) {
    throw "Missing V6 repair script: $target"
}

Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "CLR:        $($PSVersionTable.CLRVersion)"

$backup = Join-Path $backups "$runId-repair-phase008f-v6.ps1"
Copy-Item $target $backup -Force
Write-Host "Backup: $backup" -ForegroundColor Cyan

$source = (Get-Content $target -Raw).Replace("`r`n","`n")

# ------------------------------------------------------------------
# Detect the current V6 state.
#
# State A: original GetRelativePath block still exists.
# State B: V7 already replaced it with the multiline Uri block, but that
#          replacement contains PowerShell-invalid line-leading method calls.
# State C: portable block is already correct.
# ------------------------------------------------------------------

$portableMarker = '$relativeUri = $previewBaseUri.MakeRelativeUri($learnerCssUri)'

$originalMarker = '[IO.Path]::GetRelativePath('
$brokenUriMarker = '$previewBaseUri' + "`n" + '      .MakeRelativeUri('

if ($source.Contains($portableMarker)) {
    Write-Host "INFO: V6 already contains the corrected portable path block." -ForegroundColor Yellow
}
else {
    $startMarker = '$previewDir = Split-Path -Parent $previewPath'
    $endMarker = 'if ($relativeCss -ne "../../learner-web/src/index.css") {'

    $start = $source.IndexOf($startMarker)
    $end = $source.IndexOf($endMarker)

    if ($start -lt 0 -or $end -lt 0 -or $end -le $start) {
        throw "Could not safely identify the V6 relative-path section."
    }

    $replacement = @'
$previewDir = Split-Path -Parent $previewPath
$resolvedLearnerCss = (Resolve-Path $learnerCss).Path

# Windows PowerShell 5.1-safe relative-path calculation.
# Avoid Path.GetRelativePath (.NET Core API) and avoid line-leading method calls.
$previewBasePath = (Resolve-Path $previewDir).Path.TrimEnd("\") + "\"
$previewBaseUri = New-Object System.Uri($previewBasePath)
$learnerCssUri = New-Object System.Uri($resolvedLearnerCss)
$relativeUri = $previewBaseUri.MakeRelativeUri($learnerCssUri)
$relativeCss = [System.Uri]::UnescapeDataString($relativeUri.ToString()).Replace("\","/")

'@

    $source =
        $source.Substring(0,$start) +
        $replacement +
        $source.Substring($end)

    WriteText $target $source
    Write-Host "PASS: V6 relative-path block normalised to PowerShell 5.1-safe syntax" -ForegroundColor Green
}

# ------------------------------------------------------------------
# Parse V6 and print actual parser diagnostics if any.
# ------------------------------------------------------------------

$tokens = $null
$parseErrors = $null

[void][System.Management.Automation.Language.Parser]::ParseFile(
    $target,
    [ref]$tokens,
    [ref]$parseErrors
)

if ($parseErrors.Count -gt 0) {
    Write-Host ""
    Write-Host "PowerShell parser diagnostics:" -ForegroundColor Red

    foreach ($parseIssue in $parseErrors) {
        $message = "Line $($parseIssue.Extent.StartLineNumber): $($parseIssue.Message)"
        Write-Host $message -ForegroundColor Red
        Add-Content $log $message -Encoding UTF8
    }

    throw "V6 still contains parser errors after normalisation."
}

Write-Host "PASS: V6 parser validation" -ForegroundColor Green

# ------------------------------------------------------------------
# Validate the path calculation independently before running V6.
# ------------------------------------------------------------------

$previewPath = Join-Path $root "apps\ui-storybook\.storybook\preview.ts"
$learnerCss = Join-Path $root "apps\learner-web\src\index.css"

if (-not (Test-Path $previewPath)) {
    throw "Missing Storybook preview file: $previewPath"
}

if (-not (Test-Path $learnerCss)) {
    throw "Missing learner stylesheet: $learnerCss"
}

$previewDir = Split-Path -Parent $previewPath
$resolvedLearnerCss = (Resolve-Path $learnerCss).Path
$previewBasePath = (Resolve-Path $previewDir).Path.TrimEnd("\") + "\"
$previewBaseUri = New-Object System.Uri($previewBasePath)
$learnerCssUri = New-Object System.Uri($resolvedLearnerCss)
$relativeUri = $previewBaseUri.MakeRelativeUri($learnerCssUri)
$relativeCss = [System.Uri]::UnescapeDataString($relativeUri.ToString()).Replace("\","/")

Write-Host "Computed relative CSS path: $relativeCss"

if ($relativeCss -ne "../../learner-web/src/index.css") {
    throw "Relative CSS path validation failed. Expected ../../learner-web/src/index.css but received $relativeCss"
}

$resolvedTarget = [IO.Path]::GetFullPath((Join-Path $previewDir $relativeCss))

if (-not (Test-Path $resolvedTarget)) {
    throw "Computed CSS path does not resolve on disk: $resolvedTarget"
}

Write-Host "PASS: portable CSS path resolves to existing learner stylesheet" -ForegroundColor Green

# ------------------------------------------------------------------
# Run V6 directly. Do NOT run V7/V8 again; they were transitional repairs.
# ------------------------------------------------------------------

Write-Host ""
Write-Host "==> Running corrected Phase 008F V6 directly" -ForegroundColor Cyan

$args = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $target
)

if ($Commit) {
    $args += "-Commit"
}

& powershell.exe @args
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    throw "Corrected Phase 008F V6 failed with exit code $exitCode. Review the newest tools\dev\logs\phase008f-repair-v6-*.log"
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008F REPAIR V9: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
