param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$backupRoot = Join-Path $repoRoot "tools\dev\backups"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$sessionLog = Join-Path $logsRoot "phase006d-$runId.log"

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

function Backup-File {
  param(
    [Parameter(Mandatory)][string]$Path
  )

  if (-not (Test-Path $Path)) {
    return
  }

  $relative =
    $Path.Substring(
      $repoRoot.Length
    ).TrimStart("\")

  $safe =
    $relative.Replace(
      "\",
      "__"
    )

  Copy-Item `
    $Path `
    (Join-Path $backupRoot "$runId-$safe") `
    -Force
}

function Invoke-Native {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command
  )

  Log ""
  Log "==> $Name"

  $timestamp =
    Get-Date -Format "yyyyMMdd-HHmmssfff"

  $stdout =
    Join-Path $logsRoot "phase006d-$timestamp-out.log"

  $stderr =
    Join-Path $logsRoot "phase006d-$timestamp-err.log"

  $process =
    Start-Process `
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

  if (
    $process.ExitCode -ne 0
  ) {
    $diagnostic =
      Join-Path `
        $logsRoot `
        "FAILED-phase006d-$timestamp-$($Name.Replace(' ','-')).log"

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
PHASE 006D FAILED

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
  Write-Host "Phase 006D failed." -ForegroundColor Red
  Write-Host "Diagnostic: $sessionLog" -ForegroundColor Yellow

  exit 1
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006D" -ForegroundColor Cyan
Write-Host "Accessibility + Visual Regression Foundation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"


# ============================================================
# 1. Prerequisites
# ============================================================

Log ""
Log "==> Verifying Phase 006B/006C prerequisites"

$storybookPackagePath =
  Join-Path `
    $repoRoot `
    "apps\ui-storybook\package.json"

$storybookBuildDir =
  Join-Path `
    $repoRoot `
    "apps\ui-storybook\storybook-static"

$rootPackagePath =
  Join-Path `
    $repoRoot `
    "package.json"

foreach (
  $required
  in @(
    $storybookPackagePath,
    $rootPackagePath
  )
) {
  if (-not (Test-Path $required)) {
    throw "Required prerequisite missing: $required"
  }
}

Log "PASS: prerequisites exist"


# ============================================================
# 2. Create QA workspace
# ============================================================

Log ""
Log "==> Creating visual QA workspace"

$qaRoot =
  Join-Path `
    $repoRoot `
    "tools\visual-regression"

$testRoot =
  Join-Path `
    $qaRoot `
    "tests"

New-Item `
  -ItemType Directory `
  -Force `
  -Path $testRoot `
  | Out-Null


# ============================================================
# 3. Static Storybook server using Node core only
# ============================================================

$serverSource = @'
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const repoRoot =
  process.cwd();

const root =
  path.join(
    repoRoot,
    "apps",
    "ui-storybook",
    "storybook-static"
  );

const port =
  Number(
    process.env.STORYBOOK_TEST_PORT ??
    6106
  );

const mime = new Map([
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".mjs", "text/javascript; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".svg", "image/svg+xml"],
  [".png", "image/png"],
  [".jpg", "image/jpeg"],
  [".jpeg", "image/jpeg"],
  [".webp", "image/webp"],
  [".woff2", "font/woff2"]
]);

if (
  !fs.existsSync(
    root
  )
) {
  console.error(
    `Storybook static build is missing: ${root}`
  );

  process.exit(1);
}

function resolveSafe(
  requestPath
) {
  const raw =
    decodeURIComponent(
      requestPath.split("?")[0]
    );

  const requested =
    raw === "/"
      ? "/index.html"
      : raw;

  const resolved =
    path.resolve(
      root,
      "." + requested
    );

  if (
    !resolved.startsWith(
      path.resolve(root)
    )
  ) {
    return null;
  }

  return resolved;
}

const server =
  http.createServer(
    (
      request,
      response
    ) => {
      const resolved =
        resolveSafe(
          request.url ??
          "/"
        );

      if (!resolved) {
        response.writeHead(403);
        response.end("Forbidden");
        return;
      }

      let file =
        resolved;

      if (
        fs.existsSync(file) &&
        fs.statSync(file).isDirectory()
      ) {
        file =
          path.join(
            file,
            "index.html"
          );
      }

      if (
        !fs.existsSync(
          file
        )
      ) {
        response.writeHead(404);
        response.end("Not found");
        return;
      }

      response.setHeader(
        "Cache-Control",
        "no-store"
      );

      response.setHeader(
        "Content-Type",
        mime.get(
          path.extname(
            file
          ).toLowerCase()
        ) ??
        "application/octet-stream"
      );

      fs.createReadStream(
        file
      )
        .pipe(
          response
        );
    }
  );

server.listen(
  port,
  "127.0.0.1",
  () => {
    console.log(
      `Storybook test server: http://127.0.0.1:${port}`
    );
  }
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $qaRoot "serve-storybook.mjs") `
  -Content $serverSource


# ============================================================
# 4. Playwright configuration
# ============================================================

$playwrightConfig = @'
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
    [
      "list"
    ],
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
      "node tools/visual-regression/serve-storybook.mjs",

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
  -Path (Join-Path $qaRoot "playwright.config.ts") `
  -Content $playwrightConfig


# ============================================================
# 5. Accessibility tests using axe + custom learner touch-target
#    and reduced-motion checks.
# ============================================================

$a11yTest = @'
import {
  expect,
  test
} from "@playwright/test";

import AxeBuilder
  from "@axe-core/playwright";


const stories = [
  {
    name:
      "Learner audience",

    id:
      "foundations-audience--learner"
  },
  {
    name:
      "Parent audience",

    id:
      "foundations-audience--parent"
  },
  {
    name:
      "Primary button",

    id:
      "primitives-button--primary"
  },
  {
    name:
      "Gentle feedback",

    id:
      "primitives-feedbackpanel--gentle"
  }
];


for (
  const story
  of stories
) {
  test(
    `${story.name} has no serious axe violations`,
    async ({
      page
    }) => {
      await page.goto(
        `/iframe.html?id=${story.id}&viewMode=story`
      );

      await page.waitForLoadState(
        "networkidle"
      );

      const results =
        await new AxeBuilder({
          page
        })
          .withTags([
            "wcag2a",
            "wcag2aa",
            "wcag21a",
            "wcag21aa"
          ])
          .analyze();

      const serious =
        results.violations
          .filter(
            violation =>
              [
                "serious",
                "critical"
              ].includes(
                violation.impact ??
                ""
              )
          );

      expect(
        serious,
        JSON.stringify(
          serious,
          null,
          2
        )
      ).toEqual([]);
    }
  );
}


test(
  "learner buttons meet preferred 56px touch target",
  async ({
    page
  }) => {
    await page.goto(
      "/iframe.html?id=primitives-button--primary&viewMode=story"
    );

    const button =
      page.locator(
        "button"
      ).first();

    const box =
      await button.boundingBox();

    expect(
      box
    ).not.toBeNull();

    expect(
      box?.height ??
      0
    ).toBeGreaterThanOrEqual(
      56
    );
  }
);


test(
  "reduced motion suppresses meaningful transitions",
  async ({
    page
  }) => {
    await page.goto(
      "/iframe.html?id=primitives-button--primary&viewMode=story"
    );

    const button =
      page.locator(
        "button"
      ).first();

    const transitionDuration =
      await button.evaluate(
        element =>
          getComputedStyle(
            element
          ).transitionDuration
      );

    const durations =
      transitionDuration
        .split(",")
        .map(
          value =>
            value.trim()
        );

    for (
      const duration
      of durations
    ) {
      const seconds =
        duration.endsWith(
          "ms"
        )
          ? Number.parseFloat(
              duration
            ) /
            1000
          : Number.parseFloat(
              duration
            );

      expect(
        Number.isNaN(
          seconds
        )
          ? 0
          : seconds
      ).toBeLessThanOrEqual(
        0.05
      );
    }
  }
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $testRoot "accessibility.spec.ts") `
  -Content $a11yTest


# ============================================================
# 6. Visual regression tests
# ============================================================

$visualTest = @'
import {
  expect,
  test
} from "@playwright/test";


const visualStories = [
  {
    name:
      "learner-audience",

    id:
      "foundations-audience--learner"
  },
  {
    name:
      "parent-audience",

    id:
      "foundations-audience--parent"
  },
  {
    name:
      "button-primary",

    id:
      "primitives-button--primary"
  },
  {
    name:
      "button-secondary",

    id:
      "primitives-button--secondary"
  },
  {
    name:
      "feedback-success",

    id:
      "primitives-feedbackpanel--success"
  },
  {
    name:
      "feedback-gentle",

    id:
      "primitives-feedbackpanel--gentle"
  }
];


for (
  const story
  of visualStories
) {
  test(
    `${story.name} visual baseline`,
    async ({
      page
    }) => {
      await page.goto(
        `/iframe.html?id=${story.id}&viewMode=story`
      );

      await page.waitForLoadState(
        "networkidle"
      );

      await expect(
        page
      ).toHaveScreenshot(
        `${story.name}.png`,
        {
          fullPage:
            true
        }
      );
    }
  );
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $testRoot "visual.spec.ts") `
  -Content $visualTest


# ============================================================
# 7. QA policy
# ============================================================

$qaPolicy = @'
{
  "version": 1,
  "accessibility": {
    "standard": "WCAG 2.1 AA",
    "blockImpacts": [
      "serious",
      "critical"
    ],
    "learnerPreferredTouchTargetPx": 56,
    "parentMinimumTouchTargetPx": 44,
    "reducedMotionRequired": true
  },
  "visualRegression": {
    "browser": "chromium",
    "viewport": {
      "width": 1280,
      "height": 900
    },
    "deviceScaleFactor": 1,
    "locale": "ms-MY",
    "timezone": "Asia/Kuala_Lumpur",
    "maxDiffPixelRatio": 0.01,
    "baselineReviewRequired": true
  }
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $qaRoot "qa-policy.json") `
  -Content $qaPolicy


# ============================================================
# 8. Documentation
# ============================================================

$qaDoc = @'
# HIBEYA Akal Budi — Accessibility & Visual Regression

## Purpose

Phase 006D turns visual quality and accessibility into automated release gates.

## Accessibility

Automated tests use axe-core against representative Storybook stories.

Blocking impacts:

- serious
- critical

The automated standard is WCAG 2.1 AA.

Automation does not replace manual accessibility review.

## Learner interaction

Learner controls use a preferred minimum touch target of 56px.

Reduced-motion behaviour is tested with the browser preference set to `reduce`.

## Visual regression

Reference screenshots are generated in Chromium with a deterministic test profile:

- 1280 × 900 viewport
- device scale factor 1
- light colour scheme
- Malay locale
- Asia/Kuala_Lumpur timezone
- reduced motion enabled

## Baselines

Initial baselines are generated deliberately with:

```powershell
pnpm qa:visual:update
```

After baselines exist, normal validation uses:

```powershell
pnpm qa:visual
```

A baseline update must be reviewed as a visual change, not treated as an automatic fix.

## Local browser installation

Playwright Chromium is installed using:

```powershell
pnpm qa:browsers:install
```

## Commercial release principle

A release should not pass solely because TypeScript compiles.

The intended quality stack is:

```text
schema validation
→ typecheck
→ unit/integration tests
→ RLS security
→ accessibility
→ visual regression
→ production build
```
'@

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot "ACCESSIBILITY_VISUAL_QA.md") `
  -Content $qaDoc


# ============================================================
# 9. Root scripts and dependencies via Node
# ============================================================

Log ""
Log "==> Registering Playwright QA commands"

Backup-File -Path $rootPackagePath

$tempEditor =
  Join-Path `
    $env:TEMP `
    "akal-budi-phase006d-package-editor.cjs"

$editor = @'
const fs = require("fs");

const path =
  process.argv[2];

const pkg =
  JSON.parse(
    fs.readFileSync(
      path,
      "utf8"
    )
  );

pkg.scripts ??= {};

pkg.scripts["qa:browsers:install"] =
  "playwright install chromium";

pkg.scripts["qa:a11y"] =
  "playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/accessibility.spec.ts";

pkg.scripts["qa:visual"] =
  "playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/visual.spec.ts";

pkg.scripts["qa:visual:update"] =
  "playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/visual.spec.ts --update-snapshots";

pkg.scripts["qa:ui"] =
  "pnpm storybook:build && pnpm qa:a11y && pnpm qa:visual";

fs.writeFileSync(
  path,
  JSON.stringify(
    pkg,
    null,
    2
  ) + "\n",
  "utf8"
);
'@

Write-Utf8NoBom `
  -Path $tempEditor `
  -Content $editor

& node `
  $tempEditor `
  $rootPackagePath

if (
  $LASTEXITCODE -ne 0
) {
  throw "Could not register Phase 006D scripts."
}

Remove-Item `
  $tempEditor `
  -Force `
  -ErrorAction SilentlyContinue

Log "PASS: Playwright QA commands registered"


# ============================================================
# 10. Install QA dependencies
# ============================================================

Invoke-Native `
  -Name "Install QA dependencies" `
  -Command "pnpm add -Dw @playwright/test @axe-core/playwright"

Invoke-Native `
  -Name "Install Playwright Chromium" `
  -Command "pnpm qa:browsers:install"


# ============================================================
# 11. Build Storybook before QA
# ============================================================

Invoke-Native `
  -Name "Storybook production build" `
  -Command "pnpm storybook:build"


# ============================================================
# 12. Accessibility first
# ============================================================

Invoke-Native `
  -Name "Accessibility regression" `
  -Command "pnpm qa:a11y"


# ============================================================
# 13. Establish baseline if absent, then verify it immediately
# ============================================================

$snapshotRoot =
  Join-Path `
    $testRoot `
    "visual.spec.ts-snapshots"

$snapshotsExist =
  Test-Path $snapshotRoot

if (-not $snapshotsExist) {
  Invoke-Native `
    -Name "Create initial visual baselines" `
    -Command "pnpm qa:visual:update"
}
else {
  Log ""
  Log "Existing visual baselines detected; no automatic baseline rewrite."
}

Invoke-Native `
  -Name "Visual regression verification" `
  -Command "pnpm qa:visual"


# ============================================================
# 14. Existing quality gates
# ============================================================

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


# ============================================================
# 15. Optional commit
# ============================================================

if ($Commit) {
  Invoke-Native `
    -Name "Git stage" `
    -Command "git add tools/visual-regression ACCESSIBILITY_VISUAL_QA.md package.json pnpm-lock.yaml"

  Invoke-Native `
    -Name "Git commit" `
    -Command 'git commit -m "test: add accessibility and visual regression gates"'
}


Log ""
Log "PHASE 006D: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006D: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Phase 007A Original Illustration & Asset Provenance Foundation." -ForegroundColor Cyan
Write-Host "Log: $sessionLog" -ForegroundColor DarkGray
