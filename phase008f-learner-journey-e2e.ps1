param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$testsRoot = Join-Path $root "tools\visual-regression\tests"
$packagePath = Join-Path $root "package.json"

New-Item -ItemType Directory -Force -Path $logs,$testsRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008f-$runId.log"

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

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan

  Add-Content `
    $log `
    "`n==> $Name`nCOMMAND: $Command" `
    -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008f-$stamp-out.log"
  $err = Join-Path $logs "phase008f-$stamp-err.log"

  $process = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err `
    -NoNewWindow `
    -Wait `
    -PassThru

  $stdout = if (Test-Path $out) { Get-Content $out -Raw } else { "" }
  $stderr = if (Test-Path $err) { Get-Content $err -Raw } else { "" }

  if ($stdout) {
    Write-Host $stdout
    Add-Content $log $stdout -Encoding UTF8
  }

  if ($stderr) {
    Write-Host $stderr
    Add-Content $log $stderr -Encoding UTF8
  }

  if ($process.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase008f-$stamp-$($Name.Replace(' ','-')).log"

    WriteText `
      $diag `
      "COMMAND:`n$Command`n`nEXIT CODE:`n$($process.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue

  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content `
    $log `
    "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" `
    -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 008F: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008F" -ForegroundColor Cyan
Write-Host "Learner Journey End-to-End Regression" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$testPath = Join-Path $testsRoot "learner-journey.spec.ts"

WriteText $testPath @'
import {
  expect,
  test
} from "@playwright/test";

const storyUrl =
  "/iframe.html?id=learner-journey--default&viewMode=story";

test.describe(
  "learner journey",
  () => {
    test(
      "home opens explore and returns home",
      async ({
        page
      }) => {
        await page.goto(
          storyUrl
        );

        await expect(
          page.getByRole(
            "heading",
            {
              name:
                "Warna di sekeliling kita"
            }
          )
        ).toBeVisible();

        await page.getByRole(
          "button",
          {
            name:
              "Lihat aktiviti"
          }
        ).click();

        await expect(
          page.getByRole(
            "heading",
            {
              name:
                "Pilih aktiviti"
            }
          )
        ).toBeVisible();

        await page.getByRole(
          "button",
          {
            name:
              "Kembali"
          }
        ).click();

        await expect(
          page.getByRole(
            "button",
            {
              name:
                "Sambung belajar"
            }
          )
        ).toBeVisible();
      }
    );

    test(
      "explore opens the requested red activity through the typed adapter",
      async ({
        page
      }) => {
        await page.goto(
          storyUrl
        );

        await page.getByRole(
          "button",
          {
            name:
              "Lihat aktiviti"
          }
        ).click();

        await page.getByRole(
          "button",
          {
            name:
              /Kenal warna merah/
          }
        ).click();

        await expect(
          page.getByRole(
            "button",
            {
              name:
                "Keluar aktiviti"
            }
          )
        ).toBeVisible();

        await expect(
          page.getByText(
            /merah/i
          ).first()
        ).toBeVisible();
      }
    );

    test(
      "exit returns to the view that launched the activity",
      async ({
        page
      }) => {
        await page.goto(
          storyUrl
        );

        await page.getByRole(
          "button",
          {
            name:
              "Lihat aktiviti"
          }
        ).click();

        await page.getByRole(
          "button",
          {
            name:
              /Warna bunga raya/
          }
        ).click();

        await page.getByRole(
          "button",
          {
            name:
              "Keluar aktiviti"
          }
        ).click();

        await expect(
          page.getByRole(
            "heading",
            {
              name:
                "Pilih aktiviti"
            }
          )
        ).toBeVisible();
      }
    );

    test(
      "home continue opens an activity and exit returns home",
      async ({
        page
      }) => {
        await page.goto(
          storyUrl
        );

        await page.getByRole(
          "button",
          {
            name:
              "Sambung belajar"
          }
        ).click();

        await expect(
          page.getByRole(
            "button",
            {
              name:
                "Keluar aktiviti"
            }
          )
        ).toBeVisible();

        await page.getByRole(
          "button",
          {
            name:
              "Keluar aktiviti"
          }
        ).click();

        await expect(
          page.getByRole(
            "button",
            {
              name:
                "Sambung belajar"
            }
          )
        ).toBeVisible();
      }
    );

    test(
      "journey controls meet the preferred learner touch target",
      async ({
        page
      }) => {
        await page.goto(
          storyUrl
        );

        for (
          const name
          of [
            "Sambung belajar",
            "Lihat aktiviti"
          ]
        ) {
          const button =
            page.getByRole(
              "button",
              {
                name
              }
            );

          const box =
            await button
              .boundingBox();

          expect(
            box
          ).not.toBeNull();

          expect(
            box?.height ?? 0
          ).toBeGreaterThanOrEqual(
            56
          );
        }
      }
    );
  }
);
'@

Write-Host "PASS: learner journey Playwright regression created" -ForegroundColor Green

# Add a stable reusable command.
$temp = Join-Path $env:TEMP "hibeya-phase008f-package.cjs"

WriteText $temp @'
const fs = require("fs");

const file = process.argv[2];

const pkg =
  JSON.parse(
    fs.readFileSync(
      file,
      "utf8"
    )
  );

pkg.scripts ??= {};

pkg.scripts["qa:journey"] =
  "playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-journey.spec.ts";

fs.writeFileSync(
  file,
  JSON.stringify(
    pkg,
    null,
    2
  ) + "\n",
  "utf8"
);

console.log(
  "PASS: qa:journey command added"
);
'@

& node $temp $packagePath

if ($LASTEXITCODE -ne 0) {
  throw "Could not add qa:journey package command."
}

Remove-Item $temp -Force -ErrorAction SilentlyContinue

Run `
  "Storybook production build" `
  "pnpm storybook:build"

Run `
  "Learner journey end-to-end regression" `
  "pnpm qa:journey"

Run `
  "Learner web typecheck" `
  "pnpm --filter learner-web typecheck"

Run `
  "Learner web tests" `
  "pnpm --filter learner-web test"

Run `
  "Repository typecheck" `
  "pnpm typecheck"

Run `
  "All tests" `
  "pnpm test"

Run `
  "Production build" `
  "pnpm build"

Run `
  "Accessibility regression" `
  "pnpm qa:a11y"

Run `
  "Visual regression" `
  "pnpm qa:visual"

Run `
  "Git whitespace check" `
  "git diff --check"

if ($Commit) {
  Run `
    "Stage Phase 008F" `
    "git add tools/visual-regression/tests/learner-journey.spec.ts package.json"

  Run `
    "Commit Phase 008F" `
    'git commit -m "test: add learner journey end-to-end regression"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008F: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Reusable regression command:" -ForegroundColor Cyan
Write-Host "  pnpm qa:journey" -ForegroundColor White
