param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$testPath = Join-Path $root "tools\visual-regression\tests\learner-journey.spec.ts"
$indexPath = Join-Path $root "apps\ui-storybook\storybook-static\index.json"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008f-repair-v2-$runId.log"

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

function Backup([string]$Path) {
  if (-not (Test-Path $Path)) { return }

  $relative = $Path.Substring($root.Length).TrimStart("\")
  $safe = $relative.Replace("\","__")

  Copy-Item `
    $Path `
    (Join-Path $backups "$runId-$safe") `
    -Force
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan

  Add-Content `
    $log `
    "`n==> $Name`nCOMMAND: $Command" `
    -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008f-repair-v2-$stamp-out.log"
  $err = Join-Path $logs "phase008f-repair-v2-$stamp-err.log"

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
    $diag = Join-Path $logs "FAILED-phase008f-repair-v2-$stamp-$($Name.Replace(' ','-')).log"

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
  Write-Host "PHASE 008F REPAIR V2: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008F REPAIR V2" -ForegroundColor Cyan
Write-Host "Resolve Storybook story ID from generated index" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $testPath)) {
  throw "Missing learner journey test: $testPath"
}

# Rebuild first so the Storybook index we inspect is current.
Run `
  "Storybook production build" `
  "pnpm storybook:build"

if (-not (Test-Path $indexPath)) {
  throw "Storybook build succeeded but index.json is missing: $indexPath"
}

Backup $testPath

# Thoroughly inspect the generated Storybook registry instead of assuming the slug.
$inspect = Join-Path $env:TEMP "hibeya-phase008f-inspect-index.cjs"

WriteText $inspect @'
const fs = require("fs");

const file = process.argv[2];
const json = JSON.parse(fs.readFileSync(file,"utf8"));
const entries = Object.values(json.entries ?? {});

const candidates = entries.filter(entry =>
  entry &&
  (
    entry.title === "Learner/Journey" ||
    String(entry.importPath ?? "").includes("LearnerJourney.stories")
  )
);

console.log("Learner Journey Storybook candidates:");

for (const entry of candidates) {
  console.log(JSON.stringify({
    id: entry.id,
    title: entry.title,
    name: entry.name,
    type: entry.type,
    importPath: entry.importPath
  }));
}

const target = candidates.find(entry =>
  entry.type === "story" &&
  entry.name === "Default"
) ?? candidates.find(entry =>
  entry.type === "story"
);

if (!target?.id) {
  console.error("Could not resolve Learner/Journey story from generated Storybook index.");
  process.exit(1);
}

console.log(`RESOLVED_STORY_ID=${target.id}`);
'@

$inspection = & node $inspect $indexPath 2>&1
$inspectExit = $LASTEXITCODE

$inspection | ForEach-Object {
  Write-Host $_
  Add-Content $log $_ -Encoding UTF8
}

Remove-Item $inspect -Force -ErrorAction SilentlyContinue

if ($inspectExit -ne 0) {
  throw "Storybook index inspection failed."
}

$resolvedLine =
  $inspection |
  Where-Object {
    $_ -like "RESOLVED_STORY_ID=*"
  } |
  Select-Object -Last 1

if (-not $resolvedLine) {
  throw "Storybook inspection did not return a resolved story ID."
}

$resolvedStoryId =
  ($resolvedLine -replace "^RESOLVED_STORY_ID=","").Trim()

Write-Host ""
Write-Host "Resolved learner journey story ID: $resolvedStoryId" -ForegroundColor Green

# Write a test that resolves the story ID from the generated Storybook index.
# It also captures browser runtime errors so future failures are diagnostic,
# rather than five opaque locator timeouts.
WriteText $testPath @'
import fs from "node:fs";
import path from "node:path";

import {
  expect,
  test,
  type Page
} from "@playwright/test";

type StorybookEntry = {
  id?: string;
  title?: string;
  name?: string;
  type?: string;
  importPath?: string;
};

function resolveJourneyStoryId() {
  const indexFile =
    path.resolve(
      process.cwd(),
      "apps",
      "ui-storybook",
      "storybook-static",
      "index.json"
    );

  const index =
    JSON.parse(
      fs.readFileSync(
        indexFile,
        "utf8"
      )
    ) as {
      entries?: Record<
        string,
        StorybookEntry
      >;
    };

  const entries =
    Object.values(
      index.entries ??
      {}
    );

  const candidates =
    entries.filter(
      entry =>
        entry.title ===
          "Learner/Journey" ||
        String(
          entry.importPath ??
          ""
        ).includes(
          "LearnerJourney.stories"
        )
    );

  const target =
    candidates.find(
      entry =>
        entry.type ===
          "story" &&
        entry.name ===
          "Default"
    ) ??
    candidates.find(
      entry =>
        entry.type ===
        "story"
    );

  if (!target?.id) {
    throw new Error(
      `Learner/Journey story not found. Candidates: ${JSON.stringify(candidates)}`
    );
  }

  return target.id;
}

const journeyStoryId =
  resolveJourneyStoryId();

async function openJourney(
  page:
    Page
) {
  const runtimeErrors:
    string[] = [];

  page.on(
    "pageerror",
    error => {
      runtimeErrors.push(
        `PAGE ERROR: ${error.message}`
      );
    }
  );

  page.on(
    "console",
    message => {
      if (
        message.type() ===
          "error"
      ) {
        runtimeErrors.push(
          `CONSOLE ERROR: ${message.text()}`
        );
      }
    }
  );

  const response =
    await page.goto(
      `/iframe.html?id=${encodeURIComponent(journeyStoryId)}&viewMode=story`,
      {
        waitUntil:
          "networkidle"
      }
    );

  expect(
    response?.ok(),
    `Storybook iframe HTTP failure for ${journeyStoryId}`
  ).toBeTruthy();

  const homeButton =
    page.getByRole(
      "button",
      {
        name:
          "Sambung belajar"
      }
    );

  try {
    await expect(
      homeButton
    ).toBeVisible({
      timeout:
        10_000
    });
  }
  catch {
    const bodyText =
      await page.locator(
        "body"
      ).innerText()
        .catch(
          () =>
            "<body unavailable>"
        );

    throw new Error(
      [
        `Learner journey story failed to render.`,
        `Resolved Storybook ID: ${journeyStoryId}`,
        `URL: ${page.url()}`,
        `Runtime errors:`,
        runtimeErrors.length
          ? runtimeErrors.join("\n")
          : "<none captured>",
        `Body:`,
        bodyText.slice(
          0,
          4000
        )
      ].join(
        "\n"
      )
    );
  }
}

test.describe(
  "learner journey",
  () => {
    test(
      "home opens explore and returns home",
      async ({
        page
      }) => {
        await openJourney(
          page
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
        await openJourney(
          page
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
      }
    );

    test(
      "exit returns to the view that launched the activity",
      async ({
        page
      }) => {
        await openJourney(
          page
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
        await openJourney(
          page
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
        await openJourney(
          page
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

          await expect(
            button
          ).toBeVisible();

          const dimensions =
            await button.evaluate(
              element => {
                const rect =
                  element
                    .getBoundingClientRect();

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
      }
    );
  }
);
'@

Write-Host "PASS: learner journey regression now resolves Storybook ID from index.json" -ForegroundColor Green
Write-Host "PASS: browser runtime diagnostics added to story bootstrap" -ForegroundColor Green

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
  "Storybook typecheck" `
  "pnpm --filter ui-storybook typecheck"

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
    "Stage Phase 008F Repair V2" `
    "git add tools/visual-regression/tests/learner-journey.spec.ts"

  Run `
    "Commit Phase 008F Repair V2" `
    'git commit -m "test: resolve learner journey story from storybook index"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008F REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Resolved story ID: $resolvedStoryId" -ForegroundColor Cyan
