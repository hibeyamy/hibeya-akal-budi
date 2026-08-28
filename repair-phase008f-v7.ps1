param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$target = Join-Path $root "repair-phase008f-v6.ps1"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008f-repair-v7-$runId.log"

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
    Write-Host "PHASE 008F REPAIR V7: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008F REPAIR V7" -ForegroundColor Cyan
Write-Host "Windows PowerShell 5.1 path compatibility" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $target)) {
    throw "Missing V6 repair script: $target"
}

$psVersion = $PSVersionTable.PSVersion.ToString()
$clrVersion =
    if ($PSVersionTable.CLRVersion) {
        $PSVersionTable.CLRVersion.ToString()
    }
    else {
        "<not reported>"
    }

Write-Host "PowerShell: $psVersion"
Write-Host "CLR:        $clrVersion"

Add-Content $log "PowerShell=$psVersion" -Encoding UTF8
Add-Content $log "CLR=$clrVersion" -Encoding UTF8

$hasGetRelativePath =
    [System.IO.Path].GetMethods() |
    Where-Object {
        $_.Name -eq "GetRelativePath"
    } |
    Measure-Object |
    Select-Object -ExpandProperty Count

if ($hasGetRelativePath -gt 0) {
    Write-Host "INFO: GetRelativePath is available in this host." -ForegroundColor Yellow
}
else {
    Write-Host "PASS: confirmed GetRelativePath is unavailable in this Windows PowerShell host" -ForegroundColor Green
}

$backup = Join-Path $backups "$runId-repair-phase008f-v6.ps1"
Copy-Item $target $backup -Force
Write-Host "Backup: $backup" -ForegroundColor Cyan

$source = Get-Content $target -Raw
$normalised = $source.Replace("`r`n","`n")

$oldBlock = @'
$previewDir = Split-Path -Parent $previewPath
$resolvedLearnerCss = (Resolve-Path $learnerCss).Path
$relativeCss = [IO.Path]::GetRelativePath(
  $previewDir,
  $resolvedLearnerCss
).Replace("\","/")
'@

$newBlock = @'
$previewDir = Split-Path -Parent $previewPath
$resolvedLearnerCss = (Resolve-Path $learnerCss).Path

# Windows PowerShell 5.1 runs on .NET Framework, where
# System.IO.Path.GetRelativePath() is unavailable. Use Uri.MakeRelativeUri()
# instead so the script works in both Windows PowerShell 5.1 and PowerShell 7+.
$previewBasePath =
  (Resolve-Path $previewDir).Path.TrimEnd("\") + "\"

$previewBaseUri =
  New-Object System.Uri(
    $previewBasePath
  )

$learnerCssUri =
  New-Object System.Uri(
    $resolvedLearnerCss
  )

$relativeCss =
  [System.Uri]::UnescapeDataString(
    $previewBaseUri
      .MakeRelativeUri(
        $learnerCssUri
      )
      .ToString()
  ).Replace("\","/")
'@

if (-not $normalised.Contains($oldBlock)) {
    throw "Expected GetRelativePath block was not found in V6. Refusing blind patch."
}

$patched = $normalised.Replace($oldBlock,$newBlock)

WriteText $target $patched
Write-Host "PASS: V6 patched for Windows PowerShell 5.1 compatibility" -ForegroundColor Green

$tokens = $null
$errors = $null

[void][System.Management.Automation.Language.Parser]::ParseFile(
    $target,
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -gt 0) {
    foreach ($parseError in $errors) {
        Add-Content $log $parseError.Message -Encoding UTF8
    }

    throw "Patched V6 failed PowerShell parser validation."
}

Write-Host "PASS: PowerShell parser validation" -ForegroundColor Green

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

$portableRelative =
    [System.Uri]::UnescapeDataString(
        $previewBaseUri.MakeRelativeUri($learnerCssUri).ToString()
    ).Replace("\","/")

Write-Host "Computed relative CSS path: $portableRelative"

if ($portableRelative -ne "../../learner-web/src/index.css") {
    throw "Portable relative-path calculation returned unexpected result: $portableRelative"
}

$resolvedTarget =
    [IO.Path]::GetFullPath(
        (Join-Path $previewDir $portableRelative)
    )

if (-not (Test-Path $resolvedTarget)) {
    throw "Computed relative CSS path does not resolve on disk: $resolvedTarget"
}

Write-Host "PASS: portable CSS path resolves correctly on disk" -ForegroundColor Green

Write-Host ""
Write-Host "==> Re-running repaired Phase 008F V6" -ForegroundColor Cyan

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
    throw "Repaired Phase 008F V6 still failed with exit code $exitCode. Review tools\dev\logs\phase008f-repair-v6-*.log"
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008F REPAIR V7: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
