param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$qaRoot = Join-Path $repoRoot "tools\visual-regression"
$testPath = Join-Path $qaRoot "tests\accessibility.spec.ts"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$sessionLog = Join-Path $logsRoot "phase006d-repair-v4-$runId.log"

function Write-Utf8NoBom {
  param([string]$Path,[string]$Content)

  [System.IO.File]::WriteAllText(
    $Path,
    $Content.TrimEnd() + "`n",
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Log {
  param([string]$Message)

  Write-Host $Message
  Add-Content -Path $sessionLog -Value $Message -Encoding UTF8
}

function Invoke-Native {
  param([string]$Name,[string]$Command)

  Log ""
  Log "==> $Name"
  Log "COMMAND: $Command"

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logsRoot "phase006d-v4-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase006d-v4-$timestamp-err.log"

  $process = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -NoNewWindow `
    -Wait `
    -PassThru

  $outText = if (Test-Path $stdout) { Get-Content $stdout -Raw } else { "" }
  $errText = if (Test-Path $stderr) { Get-Content $stderr -Raw } else { "" }

  if ($outText) {
    Write-Host $outText
    Add-Content -Path $sessionLog -Value $outText -Encoding UTF8
  }

  if ($errText) {
    Write-Host $errText
    Add-Content -Path $sessionLog -Value $errText -Encoding UTF8
  }

  if ($process.ExitCode -ne 0) {
    $diagnostic = Join-Path $logsRoot "FAILED-phase006d-v4-$timestamp-$($Name.Replace(' ','-')).log"

    Write-Utf8NoBom `
      -Path $diagnostic `
      -Content @"
COMMAND:
$Command

EXIT CODE:
$($process.ExitCode)

STDOUT:
$outText

STDERR:
$errText
"@

    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diagnostic"
  }

  Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
  Log "PASS: $Name"
}

trap {
  Write-Utf8NoBom `
    -Path $sessionLog `
    -Content @"
PHASE 006D REPAIR V4 FAILED

TIME:
$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")

MESSAGE:
$($_.Exception.Message)

ERROR:
$($_ | Out-String)

POSITION:
$($_.InvocationInfo.PositionMessage)

STACK:
$($_.ScriptStackTrace)
"@

  Write-Host ""
  Write-Host "PHASE 006D REPAIR V4: FAILED" -ForegroundColor Red
  Write-Host "Diagnostic: $sessionLog" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006D REPAIR V4" -ForegroundColor Cyan
Write-Host "Stabilise learner touch-target test" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $testPath)) {
  throw "Accessibility test not found: $testPath"
}

$source = Get-Content $testPath -Raw

$replacement = @'
test(
  "learner buttons meet preferred 56px touch target",
  async ({
    page
  }) => {
    await page.goto(
      "/iframe.html?id=primitives-button--primary&viewMode=story"
    );

    const button =
      page.getByRole(
        "button",
        {
          name:
            "Aktiviti seterusnya"
        }
      );

    await expect(
      button
    ).toBeVisible();

    const dimensions =
      await button.evaluate(
        element => {
          const rect =
            element.getBoundingClientRect();

          return {
            width:
              rect.width,

            height:
              rect.height
          };
        }
      );

    expect(
      dimensions.height
    ).toBeGreaterThanOrEqual(
      56
    );

    expect(
      dimensions.width
    ).toBeGreaterThanOrEqual(
      56
    );
  }
);
'@

$updated = [regex]::Replace(
  $source,
  '(?s)test\(\s*"learner buttons meet preferred 56px touch target".*?\n\);',
  $replacement,
  1
)

if ($updated -eq $source) {
  throw "Could not locate the learner touch-target test block."
}

Write-Utf8NoBom -Path $testPath -Content $updated
Log "PASS: learner touch-target test patched"

$browserPath =
  [Environment]::GetEnvironmentVariable(
    "PLAYWRIGHT_BROWSERS_PATH",
    "User"
  )

if ([string]::IsNullOrWhiteSpace($browserPath)) {
  $browserPath = "D:\Development\playwright"
}

$env:PLAYWRIGHT_BROWSERS_PATH = $browserPath
Log "Playwright browsers: $browserPath"

Invoke-Native "Storybook production build" "pnpm storybook:build"
Invoke-Native "Accessibility regression" "pnpm qa:a11y"

$snapshotRoot = Join-Path $qaRoot "tests\visual.spec.ts-snapshots"

if (-not (Test-Path $snapshotRoot)) {
  Invoke-Native "Create initial visual baselines" "pnpm qa:visual:update"
}
else {
  Log ""
  Log "Existing visual baselines found; they will NOT be overwritten."
}

Invoke-Native "Visual regression verification" "pnpm qa:visual"
Invoke-Native "Design adoption validation" "pnpm design:apps:validate"
Invoke-Native "Design policy validation" "pnpm design:validate"
Invoke-Native "Repository typecheck" "pnpm typecheck"
Invoke-Native "All tests" "pnpm test"
Invoke-Native "Production build" "pnpm build"

if (Test-Path (Join-Path $repoRoot ".env.security.local")) {
  Invoke-Native `
    "RLS security regression" `
    "node --env-file=.env.security.local node_modules/vitest/vitest.mjs run tools/security-tests/rls.integration.test.ts --no-file-parallelism"
}

Invoke-Native "Content compiler check" "pnpm content:check"
Invoke-Native "Curriculum validation" "pnpm curriculum:validate"
Invoke-Native "Curriculum source validation" "pnpm curriculum:sources:validate"
Invoke-Native "Git whitespace check" "git diff --check"

if ($Commit) {
  Invoke-Native `
    "Stage Phase 006D" `
    "git add tools/visual-regression ACCESSIBILITY_VISUAL_QA.md package.json pnpm-lock.yaml"

  Invoke-Native `
    "Commit Phase 006D" `
    'git commit -m "test: add accessibility and visual regression gates"'
}

Log ""
Log "PHASE 006D REPAIR V4: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006D: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Log: $sessionLog" -ForegroundColor DarkGray
