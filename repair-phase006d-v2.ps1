param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$qaRoot = Join-Path $repoRoot "tools\visual-regression"
$configPath = Join-Path $qaRoot "playwright.config.ts"
$serverPath = Join-Path $qaRoot "serve-storybook.mjs"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$sessionLog = Join-Path $logsRoot "phase006d-repair-v2-$runId.log"

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )

  $dir = Split-Path -Parent $Path

  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

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
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command
  )

  Log ""
  Log "==> $Name"
  Log "COMMAND: $Command"

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logsRoot "phase006d-v2-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase006d-v2-$timestamp-err.log"

  $process = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @(
      "/d",
      "/s",
      "/c",
      $Command
    ) `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -NoNewWindow `
    -Wait `
    -PassThru

  $outText =
    if (Test-Path $stdout) {
      Get-Content $stdout -Raw
    }
    else {
      ""
    }

  $errText =
    if (Test-Path $stderr) {
      Get-Content $stderr -Raw
    }
    else {
      ""
    }

  if ($outText) {
    Write-Host $outText
    Add-Content -Path $sessionLog -Value $outText -Encoding UTF8
  }

  if ($errText) {
    Write-Host $errText
    Add-Content -Path $sessionLog -Value $errText -Encoding UTF8
  }

  if ($process.ExitCode -ne 0) {
    $diagnostic =
      Join-Path `
        $logsRoot `
        "FAILED-phase006d-v2-$timestamp-$($Name.Replace(' ','-')).log"

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

  Remove-Item `
    $stdout,$stderr `
    -Force `
    -ErrorAction SilentlyContinue

  Log "PASS: $Name"
}

trap {
  $details = @"
PHASE 006D REPAIR V2 FAILED

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

  Write-Utf8NoBom `
    -Path $sessionLog `
    -Content $details

  Write-Host ""
  Write-Host "PHASE 006D REPAIR V2: FAILED" -ForegroundColor Red
  Write-Host "Diagnostic: $sessionLog" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006D REPAIR V2" -ForegroundColor Cyan
Write-Host "Native process-safe runner + Playwright path fix" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $serverPath)) {
  throw "Missing prerequisite: $serverPath"
}

if (-not (Test-Path (Join-Path $repoRoot "apps\ui-storybook\package.json"))) {
  throw "Missing Storybook workspace."
}

$config = @'
import {
  defineConfig,
  devices
} from "@playwright/test";

export default defineConfig({
  testDir:
    "./tests",

  timeout:
    30_000,

  expect: {
    timeout:
      5_000,

    toHaveScreenshot: {
      animations:
        "disabled",

      caret:
        "hide",

      scale:
        "css",

      maxDiffPixelRatio:
        0.01
    }
  },

  fullyParallel:
    false,

  workers:
    1,

  retries:
    0,

  reporter: [
    ["list"],
    [
      "html",
      {
        outputFolder:
          "playwright-report",

        open:
          "never"
      }
    ]
  ],

  use: {
    baseURL:
      "http://127.0.0.1:6106",

    viewport: {
      width:
        1280,

      height:
        900
    },

    deviceScaleFactor:
      1,

    colorScheme:
      "light",

    reducedMotion:
      "reduce",

    locale:
      "ms-MY",

    timezoneId:
      "Asia/Kuala_Lumpur",

    screenshot:
      "only-on-failure",

    trace:
      "retain-on-failure"
  },

  projects: [
    {
      name:
        "chromium",

      use: {
        ...devices[
          "Desktop Chrome"
        ]
      }
    }
  ],

  webServer: {
    command:
      "node serve-storybook.mjs",

    url:
      "http://127.0.0.1:6106",

    reuseExistingServer:
      false,

    timeout:
      30_000
  }
});
'@

Write-Utf8NoBom `
  -Path $configPath `
  -Content $config

Log "PASS: Playwright config repaired"

$browserPath =
  [Environment]::GetEnvironmentVariable(
    "PLAYWRIGHT_BROWSERS_PATH",
    "User"
  )

if ([string]::IsNullOrWhiteSpace($browserPath)) {
  $browserPath =
    "D:\Development\playwright"
}

New-Item `
  -ItemType Directory `
  -Force `
  -Path $browserPath `
  | Out-Null

$env:PLAYWRIGHT_BROWSERS_PATH =
  $browserPath

Log "Playwright browsers: $browserPath"

# First validate the exact gate that previously failed.
Invoke-Native `
  -Name "Storybook production build" `
  -Command "pnpm storybook:build"

Invoke-Native `
  -Name "Accessibility regression" `
  -Command "pnpm qa:a11y"

$snapshotRoot =
  Join-Path `
    $qaRoot `
    "tests\visual.spec.ts-snapshots"

if (-not (Test-Path $snapshotRoot)) {
  Invoke-Native `
    -Name "Create initial visual baselines" `
    -Command "pnpm qa:visual:update"
}
else {
  Log ""
  Log "Existing visual baselines found; they will NOT be overwritten."
}

Invoke-Native `
  -Name "Visual regression verification" `
  -Command "pnpm qa:visual"

Invoke-Native `
  -Name "Design adoption validation" `
  -Command "pnpm design:apps:validate"

Invoke-Native `
  -Name "Design policy validation" `
  -Command "pnpm design:validate"

Invoke-Native `
  -Name "Repository typecheck" `
  -Command "pnpm typecheck"

Invoke-Native `
  -Name "All tests" `
  -Command "pnpm test"

Invoke-Native `
  -Name "Production build" `
  -Command "pnpm build"

if (
  Test-Path (
    Join-Path `
      $repoRoot `
      ".env.security.local"
  )
) {
  Invoke-Native `
    -Name "RLS security regression" `
    -Command "node --env-file=.env.security.local node_modules/vitest/vitest.mjs run tools/security-tests/rls.integration.test.ts --no-file-parallelism"
}

Invoke-Native `
  -Name "Content compiler check" `
  -Command "pnpm content:check"

Invoke-Native `
  -Name "Curriculum validation" `
  -Command "pnpm curriculum:validate"

Invoke-Native `
  -Name "Curriculum source validation" `
  -Command "pnpm curriculum:sources:validate"

Invoke-Native `
  -Name "Git whitespace check" `
  -Command "git diff --check"

if ($Commit) {
  Invoke-Native `
    -Name "Stage Phase 006D" `
    -Command "git add tools/visual-regression ACCESSIBILITY_VISUAL_QA.md package.json pnpm-lock.yaml"

  Invoke-Native `
    -Name "Commit Phase 006D" `
    -Command 'git commit -m "test: add accessibility and visual regression gates"'
}

Log ""
Log "PHASE 006D REPAIR V2: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006D: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Log: $sessionLog" -ForegroundColor DarkGray
