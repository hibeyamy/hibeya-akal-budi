param([switch]$Commit)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$qaRoot = Join-Path $repoRoot "tools\visual-regression"
$configPath = Join-Path $qaRoot "playwright.config.ts"
$serverPath = Join-Path $qaRoot "serve-storybook.mjs"
New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null
$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logsRoot "phase006d-repair-$runId.log"

function Write-Utf8NoBom {
  param([string]$Path,[string]$Content)
  [System.IO.File]::WriteAllText($Path,$Content.TrimEnd()+"`n",[System.Text.UTF8Encoding]::new($false))
}

function Run {
  param([string]$Name,[string]$Command)
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`n$Command" -Encoding UTF8
  cmd.exe /d /s /c $Command 2>&1 | Tee-Object -FilePath $log -Append
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE. Log: $log"
  }
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 006D REPAIR: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006D REPAIR" -ForegroundColor Cyan
Write-Host "Portable Playwright path resolution" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $serverPath)) { throw "Missing prerequisite: $serverPath" }
if (-not (Test-Path (Join-Path $repoRoot "apps\ui-storybook\package.json"))) { throw "Missing Storybook workspace." }

$config = @'
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  timeout: 30_000,
  expect: {
    timeout: 5_000,
    toHaveScreenshot: {
      animations: "disabled",
      caret: "hide",
      scale: "css",
      maxDiffPixelRatio: 0.01
    }
  },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [
    ["list"],
    ["html", { outputFolder: "playwright-report", open: "never" }]
  ],
  use: {
    baseURL: "http://127.0.0.1:6106",
    viewport: { width: 1280, height: 900 },
    deviceScaleFactor: 1,
    colorScheme: "light",
    reducedMotion: "reduce",
    locale: "ms-MY",
    timezoneId: "Asia/Kuala_Lumpur",
    screenshot: "only-on-failure",
    trace: "retain-on-failure"
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] }
    }
  ],
  webServer: {
    command: "node serve-storybook.mjs",
    url: "http://127.0.0.1:6106",
    reuseExistingServer: false,
    timeout: 30_000
  }
});
'@
Write-Utf8NoBom -Path $configPath -Content $config
Write-Host "PASS: Playwright config repaired" -ForegroundColor Green

$browserPath = [Environment]::GetEnvironmentVariable("PLAYWRIGHT_BROWSERS_PATH","User")
if ([string]::IsNullOrWhiteSpace($browserPath)) { $browserPath = "D:\Development\playwright" }
New-Item -ItemType Directory -Force -Path $browserPath | Out-Null
$env:PLAYWRIGHT_BROWSERS_PATH = $browserPath
Write-Host "Playwright browsers: $browserPath"

Run "Storybook production build" "pnpm storybook:build"
Run "Accessibility regression" "pnpm qa:a11y"

$snapshotRoot = Join-Path $qaRoot "tests\visual.spec.ts-snapshots"
if (-not (Test-Path $snapshotRoot)) {
  Run "Create initial visual baselines" "pnpm qa:visual:update"
} else {
  Write-Host "Existing visual baselines found; they will NOT be overwritten." -ForegroundColor Yellow
}

Run "Visual regression verification" "pnpm qa:visual"
Run "Design adoption validation" "pnpm design:apps:validate"
Run "Design policy validation" "pnpm design:validate"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Content compiler check" "pnpm content:check"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Curriculum source validation" "pnpm curriculum:sources:validate"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run "Stage Phase 006D" "git add tools/visual-regression ACCESSIBILITY_VISUAL_QA.md package.json pnpm-lock.yaml"
  Run "Commit Phase 006D" 'git commit -m "test: add accessibility and visual regression gates"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006D: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Log: $log" -ForegroundColor DarkGray
