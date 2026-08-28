Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "repair-phase008m-runner-$stamp.txt"

function Log([string]$Text = "") {
    [System.IO.File]::AppendAllText(
        $log,
        $Text + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Run([string]$Label, [string]$Command) {
    Log ""
    Log "---- $Label ----"
    Log $Command

    Write-Host ""
    Write-Host "---- $Label ----" -ForegroundColor Cyan
    Write-Host $Command

    # PowerShell 5.1 + $ErrorActionPreference=Stop can convert native STDERR
    # into NativeCommandError before $LASTEXITCODE is inspected. pnpm writes
    # lifecycle text such as "$ tsc --noEmit" to STDERR, so use Process instead.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/d /s /c `"$Command`""
    $psi.WorkingDirectory = $root
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    $stdout = New-Object System.Text.StringBuilder
    $stderr = New-Object System.Text.StringBuilder

    $outHandler = [System.Diagnostics.DataReceivedEventHandler]{
        param($sender, $event)
        if ($null -ne $event.Data) {
            [void]$stdout.AppendLine($event.Data)
            Write-Host $event.Data
        }
    }

    $errHandler = [System.Diagnostics.DataReceivedEventHandler]{
        param($sender, $event)
        if ($null -ne $event.Data) {
            [void]$stderr.AppendLine($event.Data)
            Write-Host $event.Data
        }
    }

    $process.add_OutputDataReceived($outHandler)
    $process.add_ErrorDataReceived($errHandler)

    if (-not $process.Start()) {
        throw "Could not start: $Command"
    }

    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    $process.WaitForExit()

    # Ensure async stream handlers have drained.
    $process.WaitForExit()

    $exitCode = $process.ExitCode

    $process.remove_OutputDataReceived($outHandler)
    $process.remove_ErrorDataReceived($errHandler)
    $process.Dispose()

    if ($stdout.Length -gt 0) {
        Log $stdout.ToString().TrimEnd()
    }

    if ($stderr.Length -gt 0) {
        Log $stderr.ToString().TrimEnd()
    }

    Log "EXIT CODE: $exitCode"

    if ($exitCode -ne 0) {
        throw "$Label failed with exit code $exitCode. Full compiler output is preserved in $log"
    }
}

trap {
    Log ""
    Log "PHASE 008M REPAIR: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace

    Write-Host ""
    Write-Host "PHASE 008M REPAIR: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008M REPAIR" -ForegroundColor Cyan
Write-Host "PowerShell 5.1 Native Command Runner" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "HIBEYA AKAL BUDI - PHASE 008M REPAIR"
Log "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"

# Phase 008M source changes already passed both focused Vitest suites.
# Do not rewrite them. First prove TypeScript with a runner that preserves
# real stdout/stderr and honours only the actual native exit code.
Run "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run "Next activity adaptive tests" "pnpm --filter learner-web exec vitest run src/journey/nextLearnerActivity.service.test.ts"
Run "Learner selector tests" "pnpm --filter learner-web exec vitest run src/features/play/selectLearnerActivity.test.ts"

# Resume the original Phase 008M validation chain.
Run "Learner web tests" "pnpm --filter learner-web test"
Run "Mastery validation" "pnpm mastery:validate"
Run "Content sequencing validation" "pnpm content:sequence:validate"
Run "Content eligibility validation" "pnpm content:eligibility:validate"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Storybook production build" "pnpm storybook:build"
Run "Learner journey regression" "pnpm qa:journey"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression" "pnpm qa:visual"
Run "Content compiler reproducibility" "pnpm content:check"
Run "Frozen lockfile verification" "pnpm install --frozen-lockfile"
Run "Git whitespace check" "git diff --check"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008M REPAIR: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "The Phase 008M implementation is retained." -ForegroundColor Cyan
Write-Host "Native pnpm/tsc STDERR is no longer misclassified as a PowerShell failure." -ForegroundColor Cyan
Write-Host "Full Phase 008M validation chain passed." -ForegroundColor Cyan
Write-Host "Log: $log" -ForegroundColor White
