Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008m-repair-v2-$stamp.log"

function Write-Log([string]$text = "") {
    $text | Out-File -FilePath $log -Append -Encoding utf8
}

function Invoke-NativeStep([string]$name, [string]$command) {
    Write-Host ""
    Write-Host "==> $name" -ForegroundColor Cyan
    Write-Host $command
    Write-Log ""
    Write-Log "==> $name"
    Write-Log $command

    # Windows PowerShell 5.1 turns native STDERR into ErrorRecord objects.
    # It must NOT run under ErrorActionPreference=Stop.
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = & "$env:ComSpec" /d /c $command 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }

    foreach ($line in $output) {
        $text = if ($line -is [System.Management.Automation.ErrorRecord]) {
            $line.Exception.Message
        } else {
            [string]$line
        }
        Write-Host $text
        Write-Log $text
    }

    Write-Log "EXIT CODE: $code"

    if ($code -ne 0) {
        throw "$name failed with exit code $code"
    }

    Write-Host "PASS: $name" -ForegroundColor Green
}

trap {
    Write-Log ""
    Write-Log "PHASE 008M REPAIR V2: FAILED"
    Write-Log ($_ | Out-String)
    Write-Host ""
    Write-Host "PHASE 008M REPAIR V2: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008M REPAIR V2" -ForegroundColor Cyan
Write-Host "Windows PowerShell 5.1 Native Runner Correction" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Write-Log "HIBEYA AKAL BUDI - PHASE 008M REPAIR V2"
Write-Log "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"

if ($PSVersionTable.PSVersion.Major -ne 5) {
    Write-Host "INFO: PowerShell $($PSVersionTable.PSVersion) detected; runner remains compatible."
} else {
    Write-Host "PASS: Windows PowerShell 5.1 detected" -ForegroundColor Green
}

# Diagnostic first. No Phase 008M source files are modified by this repair.
Invoke-NativeStep "Learner web typecheck" "pnpm --filter learner-web typecheck"
Invoke-NativeStep "Adaptive progression tests" "pnpm --filter learner-web exec vitest run src/journey/nextLearnerActivity.service.test.ts"
Invoke-NativeStep "Selector tests" "pnpm --filter learner-web exec vitest run src/features/play/selectLearnerActivity.test.ts"

# Only continue when the actual compiler/test gates above pass.
Invoke-NativeStep "Learner web tests" "pnpm --filter learner-web test"
Invoke-NativeStep "Mastery validation" "pnpm mastery:validate"
Invoke-NativeStep "Content sequencing validation" "pnpm content:sequence:validate"
Invoke-NativeStep "Content eligibility validation" "pnpm content:eligibility:validate"
Invoke-NativeStep "Curriculum validation" "pnpm curriculum:validate"
Invoke-NativeStep "Repository typecheck" "pnpm typecheck"
Invoke-NativeStep "All tests" "pnpm test"
Invoke-NativeStep "Production build" "pnpm build"
Invoke-NativeStep "Storybook production build" "pnpm storybook:build"
Invoke-NativeStep "Learner journey regression" "pnpm qa:journey"
Invoke-NativeStep "Accessibility regression" "pnpm qa:a11y"
Invoke-NativeStep "Visual regression" "pnpm qa:visual"
Invoke-NativeStep "Content compiler reproducibility" "pnpm content:check"
Invoke-NativeStep "Frozen lockfile verification" "pnpm install --frozen-lockfile"
Invoke-NativeStep "Git whitespace check" "git diff --check"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008M REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Phase 008M implementation and complete validation chain passed." -ForegroundColor Cyan
Write-Host "Log: $log"
