Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$target = Join-Path $root "phase007j-asset-vault.ps1"
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007j-repair-v2-$stamp.log"

function WriteUtf8([string]$Path,[string]$Text) {
    [IO.File]::WriteAllText(
        $Path,
        $Text,
        [Text.UTF8Encoding]::new($false)
    )
}

trap {
    Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
    Write-Host ""
    Write-Host "PHASE 007J REPAIR V2: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007J REPAIR V2" -ForegroundColor Cyan
Write-Host "Native process-safe command runner" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $target)) {
    throw "Missing installer: $target"
}

$backup = Join-Path $backups "$stamp-phase007j-asset-vault.ps1"
Copy-Item $target $backup -Force
Write-Host "Backup: $backup"

$text = Get-Content $target -Raw

$start = $text.IndexOf("function Run(")
$end = $text.IndexOf("trap{", $start)

if ($start -lt 0 -or $end -lt 0 -or $end -le $start) {
    throw "Could not safely locate the Phase 007J Run function."
}

$newRun = @'
function Run([string]$Name,[string]$Command) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

    $commandStamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $stdout = Join-Path $logs "phase007j-$commandStamp-stdout.log"
    $stderr = Join-Path $logs "phase007j-$commandStamp-stderr.log"

    $process = Start-Process `
        -FilePath "cmd.exe" `
        -ArgumentList @("/d", "/s", "/c", $Command) `
        -WorkingDirectory $root `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -NoNewWindow `
        -Wait `
        -PassThru

    $outText = if (Test-Path $stdout) {
        Get-Content $stdout -Raw -ErrorAction SilentlyContinue
    } else {
        ""
    }

    $errText = if (Test-Path $stderr) {
        Get-Content $stderr -Raw -ErrorAction SilentlyContinue
    } else {
        ""
    }

    if ($outText) {
        Write-Host $outText
        Add-Content $log "`nSTDOUT:`n$outText" -Encoding UTF8
    }

    if ($errText) {
        # stderr is diagnostic output only. Native tools such as pnpm can
        # legitimately write progress/output here even when exit code is 0.
        Write-Host $errText
        Add-Content $log "`nSTDERR:`n$errText" -Encoding UTF8
    }

    $exitCode = $process.ExitCode

    if ($exitCode -ne 0) {
        $diagnostic = Join-Path $logs "phase007j-command-failure-$commandStamp.log"

        $diagnosticText = @"
PHASE 007J COMMAND FAILURE
NAME: $Name
COMMAND: $Command
EXIT CODE: $exitCode

STDOUT:
$outText

STDERR:
$errText
"@

        [IO.File]::WriteAllText(
            $diagnostic,
            $diagnosticText,
            [Text.UTF8Encoding]::new($false)
        )

        throw "$Name failed with exit code $exitCode. Diagnostic: $diagnostic"
    }

    Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
    Write-Host "PASS: $Name" -ForegroundColor Green
}

'@

$patched = $text.Substring(0,$start) + $newRun + $text.Substring($end)
WriteUtf8 $target $patched

# Parser check before execution.
$tokens = $null
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $target,
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Add-Content $log $_.Message -Encoding UTF8 }
    throw "Patched Phase 007J failed PowerShell parser validation."
}

Write-Host "PASS: Phase 007J command runner repaired" -ForegroundColor Green
Write-Host ""
Write-Host "==> Re-running Phase 007J" -ForegroundColor Cyan

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    throw "Repaired Phase 007J still failed with exit code $exitCode. Review the Phase 007J diagnostic log."
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007J REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
