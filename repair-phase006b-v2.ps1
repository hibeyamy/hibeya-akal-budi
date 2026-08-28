param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$phasePath = Join-Path $repoRoot "phase006b-shared-ui-storybook.ps1"
$backupRoot = Join-Path $repoRoot "tools\dev\backups"

New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

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

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006B REPAIR V2" -ForegroundColor Cyan
Write-Host "Fix PowerShell strict-mode hashtable assignments" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $phasePath)) {
  throw "Phase 006B installer not found: $phasePath"
}

Write-Step "Backing up current Phase 006B installer"

$timestamp =
  Get-Date -Format "yyyyMMdd-HHmmss"

Copy-Item `
  $phasePath `
  (Join-Path $backupRoot "$timestamp-phase006b-shared-ui-storybook.ps1") `
  -Force


Write-Step "Repairing hashtable assignments"

$content =
  Get-Content $phasePath -Raw

$replacements = @(
  @{
    Old = '$uiPackage.devDependencies.''@types/react'' = $typesReactVersion'
    New = '$uiPackage["devDependencies"]["@types/react"] = $typesReactVersion'
  },
  @{
    Old = '$uiPackage.devDependencies.''@types/react-dom'' = $typesReactDomVersion'
    New = '$uiPackage["devDependencies"]["@types/react-dom"] = $typesReactDomVersion'
  },
  @{
    Old = '$uiPackage.devDependencies.typescript ='
    New = '$uiPackage["devDependencies"]["typescript"] ='
  },
  @{
    Old = '$storybookPackage.devDependencies.''@types/react'' = $typesReactVersion'
    New = '$storybookPackage["devDependencies"]["@types/react"] = $typesReactVersion'
  },
  @{
    Old = '$storybookPackage.devDependencies.''@types/react-dom'' = $typesReactDomVersion'
    New = '$storybookPackage["devDependencies"]["@types/react-dom"] = $typesReactDomVersion'
  }
)

$changed =
  $false

foreach ($replacement in $replacements) {
  if (
    $content.Contains(
      $replacement.Old
    )
  ) {
    $content =
      $content.Replace(
        $replacement.Old,
        $replacement.New
      )

    $changed =
      $true
  }
}

if (-not $changed) {
  if (
    $content.Contains(
      '$uiPackage["devDependencies"]["typescript"]'
    )
  ) {
    Write-Host "Installer already appears repaired." -ForegroundColor Yellow
  }
  else {
    throw "Expected Phase 006B hashtable assignment patterns were not found. No speculative edits were made."
  }
}

Write-Utf8NoBom `
  -Path $phasePath `
  -Content $content


Write-Step "Running repaired Phase 006B"

$arguments = @(
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  $phasePath
)

if ($Commit) {
  $arguments +=
    "-Commit"
}

& powershell.exe @arguments

$exitCode =
  $LASTEXITCODE

if ($exitCode -ne 0) {
  throw "Repaired Phase 006B still failed with exit code $exitCode. Review the latest tools\dev\logs diagnostic."
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006B REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
