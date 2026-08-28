Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$workDir = Join-Path $logs "phase008r3a-visual-review-harness-$stamp"
$rawLog = Join-Path $workDir "phase008r3a.log"
$zipLog = Join-Path $logs "phase008r3a-visual-review-harness-$stamp.zip"
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

$manifestPath = Join-Path $root "content\activity-manifests\beza-bunga-raya-001.json"
$storyPath = Join-Path $root "apps\ui-storybook\stories\DraftActivityVisualReview.stories.tsx"
$testPath = Join-Path $root "tools\visual-regression\tests\draft-activity-visual-review.spec.ts"

function Log([string]$Text = "") {
    Add-Content -Path $rawLog -Value $Text -Encoding UTF8
}

function WriteUtf8([string]$Path,[string]$Content) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) {
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
    $safe = $relative -replace '[\\/:*?"<>|]', '_'
    Copy-Item $Path (Join-Path $backups "$stamp-$safe") -Force
}

function Zip-Logs {
    if (Test-Path $zipLog) {
        Remove-Item $zipLog -Force -ErrorAction SilentlyContinue
    }

    Compress-Archive `
        -Path (Join-Path $workDir "*") `
        -DestinationPath $zipLog `
        -Force
}

function Native([string]$Name,[string]$Command) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Write-Host $Command
    Log ""
    Log "==> $Name"
    Log $Command

    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & "$env:ComSpec" /d /c $Command 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $old
    }

    foreach ($item in $output) {
        $text = if ($item -is [System.Management.Automation.ErrorRecord]) {
            $item.Exception.Message
        } else {
            [string]$item
        }
        Write-Host $text
        Log $text
    }

    Log "EXIT CODE: $code"

    if ($code -ne 0) {
        throw "$Name failed with exit code $code"
    }

    Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
    Log ""
    Log "PHASE 008R3A: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    Zip-Logs

    Write-Host ""
    Write-Host "PHASE 008R3A: FAILED" -ForegroundColor Red
    Write-Host "Diagnostic ZIP: $zipLog" -ForegroundColor Yellow
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A" -ForegroundColor Cyan
Write-Host "Isolated Draft Visual Review Harness" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $manifestPath)) {
    throw "Draft manifest missing: $manifestPath"
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

if (
    $manifest.catalogue.enabled -ne $false -or
    $manifest.activity.metadata.active -ne $false -or
    $manifest.activity.provenance.originalityReviewed -ne $false -or
    $manifest.activity.provenance.culturalReviewed -ne $false
) {
    throw "Draft governance state is not safe for isolated visual review."
}

$options = @($manifest.activity.options)
$correct = @($options | Where-Object { $_.correct -eq $true })

if ($options.Count -ne 3) {
    throw "Expected exactly 3 draft options; found $($options.Count)."
}

if ($correct.Count -ne 1) {
    throw "Expected exactly 1 correct draft option; found $($correct.Count)."
}

Write-Host "PASS: safe draft and exact visual contract verified" -ForegroundColor Green

Backup $storyPath
Backup $testPath

# Generate the review fixture FROM the governed manifest, rather than
# duplicating content by hand.
$optionTs = @()

foreach ($option in $options) {
    $id = ([string]$option.id).Replace('\','\\').Replace('"','\"')
    $asset = ([string]$option.asset).Replace('\','\\').Replace('"','\"')
    $correctLiteral = if ($option.correct) { "true" } else { "false" }

    $optionTs += @"
    {
      id: "$id",
      asset: "$asset",
      correct: $correctLiteral
    }
"@
}

$titleMs = ([string]$manifest.activity.title.ms).Replace('\','\\').Replace('"','\"')
$titleEn = ([string]$manifest.activity.title.en).Replace('\','\\').Replace('"','\"')
$instructionMs = ([string]$manifest.activity.instruction.ms).Replace('\','\\').Replace('"','\"')
$instructionEn = ([string]$manifest.activity.instruction.en).Replace('\','\\').Replace('"','\"')
$activityId = ([string]$manifest.activity.id).Replace('\','\\').Replace('"','\"')
$optionsJoined = $optionTs -join ",`n"

$story = @"
import {
  useState
} from "react";

import {
  getAsset
} from "@akal-budi/assets";


const reviewActivity = {
  id:
    "$activityId",

  title: {
    ms:
      "$titleMs",

    en:
      "$titleEn"
  },

  instruction: {
    ms:
      "$instructionMs",

    en:
      "$instructionEn"
  },

  options: [
$optionsJoined
  ]
} as const;


function DraftActivityVisualReview() {
  const [
    selectedId,
    setSelectedId
  ] =
    useState<string | null>(
      null
    );

  const [
    feedback,
    setFeedback
  ] =
    useState<string | null>(
      null
    );


  function handleAnswer(
    optionId: string
  ) {
    const option =
      reviewActivity.options.find(
        item =>
          item.id ===
          optionId
      );

    if (!option) {
      return;
    }

    setSelectedId(
      optionId
    );

    setFeedback(
      option.correct
        ? "Betul! Bagus."
        : "Cuba lagi."
    );
  }


  return (
    <main
      data-review-activity-id={
        reviewActivity.id
      }
      data-review-only="true"
      className="mx-auto flex min-h-screen max-w-3xl flex-col px-4 py-6 sm:px-6 sm:py-10"
    >
      <header className="mb-8">
        <div className="inline-flex rounded-full bg-amber-100 px-3 py-1 text-xs font-extrabold uppercase tracking-[0.16em] text-amber-800">
          Draf - semakan visual sahaja
        </div>

        <p className="mt-4 text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
          HIBEYA
        </p>

        <h1 className="mt-1 text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">
          Akal Budi
        </h1>

        <p className="mt-1 text-sm text-slate-600 sm:text-base">
          Membina Akal. Menyemai Budi.
        </p>
      </header>

      <section className="rounded-[2rem] bg-white p-5 shadow-sm sm:p-8">
        <div className="mb-7 text-center">
          <p className="text-sm font-semibold text-amber-700">
            Semakan aktiviti draf
          </p>

          <h2 className="mt-2 text-2xl font-bold text-slate-900 sm:text-3xl">
            {reviewActivity.title.ms}
          </h2>

          <p className="mt-3 text-lg text-slate-700 sm:text-xl">
            {reviewActivity.instruction.ms}
          </p>

          <p className="mt-2 text-sm text-slate-500">
            {reviewActivity.title.en} - {reviewActivity.instruction.en}
          </p>
        </div>

        <div
          data-testid="draft-choice-grid"
          className="grid grid-cols-1 gap-4 sm:grid-cols-3"
        >
          {reviewActivity.options.map(
            option => {
              const asset =
                getAsset(
                  option.asset
                );

              const isSelected =
                selectedId ===
                option.id;

              return (
                <button
                  key={option.id}
                  type="button"
                  data-testid="draft-choice"
                  data-option-id={option.id}
                  data-correct={
                    option.correct
                      ? "true"
                      : "false"
                  }
                  onClick={
                    () =>
                      handleAnswer(
                        option.id
                      )
                  }
                  aria-label={
                    asset.alt.ms
                  }
                  className={[
                    "flex min-h-40 touch-manipulation flex-col items-center justify-center",
                    "rounded-3xl border-2 px-4 py-6",
                    "transition duration-150 active:scale-95",
                    "focus:outline-none focus:ring-4 focus:ring-amber-200",
                    isSelected
                      ? "border-amber-500 bg-amber-50"
                      : "border-slate-200 bg-slate-50 hover:border-amber-300"
                  ].join(" ")}
                >
                  {asset.type === "image"
                    ? (
                        <img
                          src={asset.value}
                          alt=""
                          aria-hidden="true"
                          draggable={false}
                          data-asset-id={option.asset}
                          className="h-40 w-40 select-none object-contain sm:h-44 sm:w-44"
                        />
                      )
                    : (
                        <span
                          aria-hidden="true"
                          data-asset-id={option.asset}
                          className="text-7xl sm:text-8xl"
                        >
                          {asset.value}
                        </span>
                      )
                  }

                  <span className="mt-4 text-base font-semibold text-slate-700">
                    {asset.alt.ms}
                  </span>
                </button>
              );
            }
          )}
        </div>

        <div
          className="mt-7 min-h-10 text-center text-xl font-bold text-slate-800"
          aria-live="polite"
        >
          {feedback}
        </div>

        <aside className="mt-6 rounded-3xl border border-dashed border-amber-300 bg-amber-50 p-4 text-sm leading-6 text-amber-950">
          Draf ini tidak berada dalam katalog pembelajaran produksi.
          Interaksi di halaman ini adalah untuk semakan visual sahaja dan tidak merekod kemajuan, sesi atau penguasaan kemahiran.
        </aside>
      </section>
    </main>
  );
}


export default {
  title:
    "Review/Draft Activity"
};


export function BezaBungaRaya001() {
  return (
    <DraftActivityVisualReview />
  );
}
"@

WriteUtf8 $storyPath $story

$test = @'
import {
  expect,
  test
} from "@playwright/test";


const storyId =
  "review-draft-activity--beza-bunga-raya-001";


async function openReview(
  page:
    import("@playwright/test").Page
) {
  const response =
    await page.goto(
      `/iframe.html?id=${storyId}&viewMode=story`,
      {
        waitUntil:
          "domcontentloaded"
      }
    );

  expect(
    response?.ok(),
    `Storybook iframe HTTP failure for ${storyId}`
  ).toBeTruthy();

  await expect(
    page.locator(
      '[data-review-activity-id="beza-bunga-raya-001"]'
    )
  ).toBeVisible();
}


test.describe(
  "draft activity visual review",
  () => {
    test(
      "renders the governed three-choice contract without production state",
      async ({
        page
      }) => {
        await openReview(
          page
        );

        await expect(
          page.getByText(
            "Draf - semakan visual sahaja"
          )
        ).toBeVisible();

        await expect(
          page.getByRole(
            "heading",
            {
              name:
                "Yang Mana Berbeza?"
            }
          )
        ).toBeVisible();

        await expect(
          page.getByText(
            "Cari bunga raya yang berbeza"
          )
        ).toBeVisible();

        const choices =
          page.getByTestId(
            "draft-choice"
          );

        await expect(
          choices
        ).toHaveCount(
          3
        );

        await expect(
          page.locator(
            '[data-asset-id="hibiscus-red"]'
          )
        ).toHaveCount(
          2
        );

        await expect(
          page.locator(
            '[data-asset-id="hibiscus-yellow"]'
          )
        ).toHaveCount(
          1
        );

        await expect(
          page.locator(
            '[data-testid="draft-choice"][data-correct="true"]'
          )
        ).toHaveCount(
          1
        );

        await page.locator(
          '[data-testid="draft-choice"][data-correct="false"]'
        ).first().click();

        await expect(
          page.getByText(
            "Cuba lagi."
          )
        ).toBeVisible();

        await page.locator(
          '[data-testid="draft-choice"][data-correct="true"]'
        ).click();

        await expect(
          page.getByText(
            "Betul! Bagus."
          )
        ).toBeVisible();
      }
    );


    for (
      const viewport of [
        {
          name:
            "mobile",
          width:
            390,
          height:
            844
        },
        {
          name:
            "tablet",
          width:
            768,
          height:
            1024
        },
        {
          name:
            "desktop",
          width:
            1440,
          height:
            1000
        }
      ]
    ) {
      test(
        `meets visual and touch-target contract on ${viewport.name}`,
        async ({
          page
        }) => {
          await page.setViewportSize({
            width:
              viewport.width,
            height:
              viewport.height
          });

          await openReview(
            page
          );

          const choices =
            page.getByTestId(
              "draft-choice"
            );

          await expect(
            choices
          ).toHaveCount(
            3
          );

          for (
            let index = 0;
            index < 3;
            index += 1
          ) {
            const box =
              await choices
                .nth(index)
                .boundingBox();

            expect(
              box,
              `choice ${index + 1} must have a bounding box`
            ).not.toBeNull();

            expect(
              box!.height,
              `choice ${index + 1} must meet >=56px touch height`
            ).toBeGreaterThanOrEqual(
              56
            );

            expect(
              box!.width,
              `choice ${index + 1} must meet >=56px touch width`
            ).toBeGreaterThanOrEqual(
              56
            );
          }

          await expect(
            page.locator(
              'img[data-asset-id="hibiscus-red"]'
            ).first()
          ).toBeVisible();

          await expect(
            page.locator(
              'img[data-asset-id="hibiscus-yellow"]'
            )
          ).toBeVisible();

          await page.screenshot({
            path:
              `test-results/draft-review-${viewport.name}.png`,
            fullPage:
              true
          });
        }
      );
    }
  }
);
'@

WriteUtf8 $testPath $test

Write-Host "PASS: isolated Storybook review fixture generated from governed manifest" -ForegroundColor Green
Write-Host "PASS: review harness has no offline/session/mastery/progression writes" -ForegroundColor Green
Write-Host "PASS: production catalogue and activity registry remain untouched" -ForegroundColor Green

Native "Storybook production build" "pnpm --filter ui-storybook build-storybook"
Native "Draft visual review E2E" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/draft-activity-visual-review.spec.ts"
Native "Learner web typecheck" "pnpm --filter learner-web typecheck"
Native "Learner web tests" "pnpm --filter learner-web test"
Native "Content compiler reproducibility" "pnpm content:check"

Write-Host ""
Write-Host "==> Coverage remains draft-only" -ForegroundColor Cyan
$oldPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $coverageOutput = & "$env:ComSpec" /d /c "pnpm content:coverage:validate" 2>&1
    $coverageCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $oldPreference
}

$coverageLines = @()
foreach ($item in $coverageOutput) {
    $text = if ($item -is [System.Management.Automation.ErrorRecord]) {
        $item.Exception.Message
    } else {
        [string]$item
    }
    $coverageLines += $text
    Write-Host $text
    Log $text
}

$coverageText = $coverageLines -join "`n"

if ($coverageCode -eq 0) {
    throw "Coverage unexpectedly passed while the reviewed activity is still a draft."
}

if (
    $coverageText -notmatch "visual-discrimination" -or
    $coverageText -notmatch "draft-primary=1"
) {
    throw "Coverage no longer reports the expected visual-discrimination draft gap."
}

Write-Host "PASS: draft remains excluded from released coverage" -ForegroundColor Green

Native "Git whitespace check" "git diff --check"

Log ""
Log "PHASE 008R3A: PASS"
Log "Visual review harness created."
Log "Screenshots are in test-results on the local machine."
Log "No production catalogue or review flags were changed."

Zip-Logs

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008R3A: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Visual review harness is ready." -ForegroundColor Cyan
Write-Host ""
Write-Host "REVIEW HERE:" -ForegroundColor Yellow
Write-Host "  apps\ui-storybook\storybook-static\index.html" -ForegroundColor White
Write-Host "  Story: Review / Draft Activity / Beza Bunga Raya 001" -ForegroundColor White
Write-Host ""
Write-Host "Automated screenshots:" -ForegroundColor Yellow
Write-Host "  test-results\draft-review-mobile.png" -ForegroundColor White
Write-Host "  test-results\draft-review-tablet.png" -ForegroundColor White
Write-Host "  test-results\draft-review-desktop.png" -ForegroundColor White
Write-Host ""
Write-Host "Do NOT change enabled/active/review flags manually." -ForegroundColor Yellow
Write-Host "After visual approval, Phase 008R3B will perform governed promotion." -ForegroundColor Yellow
Write-Host "Diagnostic ZIP: $zipLog" -ForegroundColor White

Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
