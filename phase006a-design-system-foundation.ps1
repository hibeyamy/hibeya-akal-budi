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

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )

  $directory = Split-Path -Parent $Path

  if ($directory -and -not (Test-Path $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  [System.IO.File]::WriteAllText(
    $Path,
    $Content.TrimEnd() + "`n",
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Backup-File {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return
  }

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $relative = $Path.Substring($repoRoot.Length).TrimStart('\')
  $safe = $relative.Replace('\', '__')

  Copy-Item `
    $Path `
    (Join-Path $backupRoot "$timestamp-$safe") `
    -Force
}

function Invoke-Native {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command
  )

  Write-Step $Name

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logsRoot "phase006a-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase006a-$timestamp-err.log"

  $process = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d", "/s", "/c", $Command) `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -NoNewWindow `
    -Wait `
    -PassThru

  $outText = if (Test-Path $stdout) { Get-Content $stdout -Raw } else { "" }
  $errText = if (Test-Path $stderr) { Get-Content $stderr -Raw } else { "" }

  if ($outText) { Write-Host $outText }
  if ($errText) { Write-Host $errText }

  if ($process.ExitCode -ne 0) {
    $diagnostic = Join-Path $logsRoot "FAILED-phase006a-$timestamp-$($Name.Replace(' ','-')).log"

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
  Write-Host "PASS: $Name" -ForegroundColor Green
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006A" -ForegroundColor Cyan
Write-Host "Design System Foundation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan


# ============================================================
# 1. Create design-system package from an existing workspace
#    TypeScript package template for compatibility.
# ============================================================

Write-Step "Creating @akal-budi/design-system package"

$templatePackagePath =
  Join-Path $repoRoot "packages\content-schema\package.json"

$templateTsconfigPath =
  Join-Path $repoRoot "packages\content-schema\tsconfig.json"

if (-not (Test-Path $templatePackagePath)) {
  throw "packages\content-schema\package.json is required as workspace template."
}

if (-not (Test-Path $templateTsconfigPath)) {
  throw "packages\content-schema\tsconfig.json is required as workspace template."
}

$designRoot =
  Join-Path $repoRoot "packages\design-system"

New-Item `
  -ItemType Directory `
  -Force `
  -Path (Join-Path $designRoot "src\__tests__") `
  | Out-Null

$templatePackage =
  Get-Content $templatePackagePath -Raw |
  ConvertFrom-Json

$templatePackage.name =
  "@akal-budi/design-system"

$packageText =
  $templatePackage |
  ConvertTo-Json -Depth 100

Write-Utf8NoBom `
  -Path (Join-Path $designRoot "package.json") `
  -Content $packageText

Copy-Item `
  $templateTsconfigPath `
  (Join-Path $designRoot "tsconfig.json") `
  -Force


# ============================================================
# 2. Canonical design tokens.
# ============================================================

Write-Step "Creating semantic design tokens"

$tokensTs = @'
export const colourTokens = {
  brand: {
    ink:
      "#1F2937",

    warm:
      "#B45309",

    soft:
      "#FFF7ED"
  },

  surface: {
    page:
      "#FFFDF8",

    card:
      "#FFFFFF",

    subtle:
      "#F8FAFC"
  },

  text: {
    primary:
      "#1F2937",

    secondary:
      "#475569",

    muted:
      "#64748B",

    inverse:
      "#FFFFFF"
  },

  feedback: {
    successSurface:
      "#ECFDF5",

    successText:
      "#065F46",

    gentleSurface:
      "#FFFBEB",

    gentleText:
      "#92400E",

    errorSurface:
      "#FEF2F2",

    errorText:
      "#991B1B"
  },

  focus: {
    ring:
      "#F59E0B"
  }
} as const;


export const spacingTokens = {
  xs:
    "0.25rem",

  sm:
    "0.5rem",

  md:
    "1rem",

  lg:
    "1.5rem",

  xl:
    "2rem",

  "2xl":
    "3rem"
} as const;


export const radiusTokens = {
  sm:
    "0.75rem",

  md:
    "1rem",

  lg:
    "1.5rem",

  xl:
    "2rem",

  round:
    "9999px"
} as const;


export const typographyTokens = {
  family: {
    ui:
      "system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
  },

  size: {
    xs:
      "0.75rem",

    sm:
      "0.875rem",

    base:
      "1rem",

    lg:
      "1.125rem",

    xl:
      "1.25rem",

    "2xl":
      "1.5rem",

    "3xl":
      "1.875rem",

    "4xl":
      "2.25rem"
  },

  weight: {
    regular:
      400,

    medium:
      500,

    semibold:
      600,

    bold:
      700
  },

  lineHeight: {
    compact:
      1.2,

    normal:
      1.5,

    relaxed:
      1.7
  }
} as const;


export const motionTokens = {
  duration: {
    instant:
      "0ms",

    quick:
      "120ms",

    gentle:
      "180ms"
  },

  easing: {
    standard:
      "cubic-bezier(0.2, 0, 0, 1)"
  }
} as const;


export const interactionTokens = {
  minTouchTargetPx:
    44,

  learnerPreferredTouchTargetPx:
    56,

  focusRingPx:
    4,

  learnerMaxChoicesPerRow:
    3
} as const;


export const wellbeingDesignRules = {
  flashingAllowed:
    false,

  autoPlayCelebrationAllowed:
    false,

  infiniteScrollAllowed:
    false,

  streakPressureAllowed:
    false,

  lossAversionAllowed:
    false,

  countdownPressureAllowed:
    false,

  reducedMotionRequired:
    true,

  gentleFeedbackRequired:
    true
} as const;


export const designTokens = {
  colour:
    colourTokens,

  spacing:
    spacingTokens,

  radius:
    radiusTokens,

  typography:
    typographyTokens,

  motion:
    motionTokens,

  interaction:
    interactionTokens,

  wellbeing:
    wellbeingDesignRules
} as const;


export type DesignTokens =
  typeof designTokens;
'@

Write-Utf8NoBom `
  -Path (Join-Path $designRoot "src\tokens.ts") `
  -Content $tokensTs


# ============================================================
# 3. CSS custom-property output.
# ============================================================

Write-Step "Creating CSS semantic token layer"

$tokensCss = @'
:root {
  --ab-brand-ink: #1f2937;
  --ab-brand-warm: #b45309;
  --ab-brand-soft: #fff7ed;

  --ab-surface-page: #fffdf8;
  --ab-surface-card: #ffffff;
  --ab-surface-subtle: #f8fafc;

  --ab-text-primary: #1f2937;
  --ab-text-secondary: #475569;
  --ab-text-muted: #64748b;
  --ab-text-inverse: #ffffff;

  --ab-feedback-success-surface: #ecfdf5;
  --ab-feedback-success-text: #065f46;
  --ab-feedback-gentle-surface: #fffbeb;
  --ab-feedback-gentle-text: #92400e;
  --ab-feedback-error-surface: #fef2f2;
  --ab-feedback-error-text: #991b1b;

  --ab-focus-ring: #f59e0b;

  --ab-space-xs: 0.25rem;
  --ab-space-sm: 0.5rem;
  --ab-space-md: 1rem;
  --ab-space-lg: 1.5rem;
  --ab-space-xl: 2rem;
  --ab-space-2xl: 3rem;

  --ab-radius-sm: 0.75rem;
  --ab-radius-md: 1rem;
  --ab-radius-lg: 1.5rem;
  --ab-radius-xl: 2rem;
  --ab-radius-round: 9999px;

  --ab-motion-quick: 120ms;
  --ab-motion-gentle: 180ms;
  --ab-motion-ease-standard: cubic-bezier(0.2, 0, 0, 1);
}


@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    scroll-behavior: auto !important;
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}


[data-ab-audience="learner"] {
  --ab-touch-target-min: 56px;
}


[data-ab-audience="parent"] {
  --ab-touch-target-min: 44px;
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $designRoot "src\tokens.css") `
  -Content $tokensCss


# ============================================================
# 4. Design contracts for future component library.
# ============================================================

Write-Step "Creating audience-specific design contracts"

$contractsTs = @'
export type Audience =
  | "learner"
  | "parent";


export interface AudienceDesignContract {
  audience:
    Audience;

  minimumTouchTargetPx:
    number;

  readingDensity:
    "very-low"
    | "low"
    | "normal";

  motion:
    "minimal"
    | "standard";

  visualComplexity:
    "low"
    | "moderate";

  destructiveActionsRequireConfirmation:
    boolean;
}


export const learnerDesignContract:
  AudienceDesignContract = {
    audience:
      "learner",

    minimumTouchTargetPx:
      56,

    readingDensity:
      "very-low",

    motion:
      "minimal",

    visualComplexity:
      "low",

    destructiveActionsRequireConfirmation:
      true
  };


export const parentDesignContract:
  AudienceDesignContract = {
    audience:
      "parent",

    minimumTouchTargetPx:
      44,

    readingDensity:
      "normal",

    motion:
      "standard",

    visualComplexity:
      "moderate",

    destructiveActionsRequireConfirmation:
      true
  };


export function getAudienceDesignContract(
  audience:
    Audience
): AudienceDesignContract {
  return audience ===
    "learner"
    ? learnerDesignContract
    : parentDesignContract;
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $designRoot "src\contracts.ts") `
  -Content $contractsTs


# ============================================================
# 5. Public package exports.
# ============================================================

Write-Step "Creating design-system exports"

$indexTs = @'
export {
  colourTokens,
  designTokens,
  interactionTokens,
  motionTokens,
  radiusTokens,
  spacingTokens,
  typographyTokens,
  wellbeingDesignRules
} from "./tokens";


export {
  getAudienceDesignContract,
  learnerDesignContract,
  parentDesignContract
} from "./contracts";


export type {
  DesignTokens
} from "./tokens";


export type {
  Audience,
  AudienceDesignContract
} from "./contracts";
'@

Write-Utf8NoBom `
  -Path (Join-Path $designRoot "src\index.ts") `
  -Content $indexTs


# ============================================================
# 6. Design-system tests.
# ============================================================

Write-Step "Creating design-system tests"

$tests = @'
import {
  describe,
  expect,
  it
} from "vitest";

import {
  designTokens,
  getAudienceDesignContract,
  wellbeingDesignRules
} from "../index";


describe(
  "design-system foundation",
  () => {

    it(
      "keeps learner touch targets larger than parent minimums",
      () => {

        const learner =
          getAudienceDesignContract(
            "learner"
          );

        const parent =
          getAudienceDesignContract(
            "parent"
          );


        expect(
          learner.minimumTouchTargetPx
        ).toBeGreaterThan(
          parent.minimumTouchTargetPx
        );
      }
    );


    it(
      "forbids pressure-based learner interaction patterns",
      () => {

        expect(
          wellbeingDesignRules
            .streakPressureAllowed
        ).toBe(false);

        expect(
          wellbeingDesignRules
            .lossAversionAllowed
        ).toBe(false);

        expect(
          wellbeingDesignRules
            .countdownPressureAllowed
        ).toBe(false);

        expect(
          wellbeingDesignRules
            .infiniteScrollAllowed
        ).toBe(false);
      }
    );


    it(
      "requires reduced-motion support",
      () => {

        expect(
          designTokens
            .wellbeing
            .reducedMotionRequired
        ).toBe(true);
      }
    );


    it(
      "keeps focus indication explicit",
      () => {

        expect(
          designTokens
            .interaction
            .focusRingPx
        ).toBeGreaterThanOrEqual(
          2
        );
      }
    );

  }
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $designRoot "src\__tests__\design-system.test.ts") `
  -Content $tests


# ============================================================
# 7. Machine-readable design contract + validator.
# ============================================================

Write-Step "Creating machine-readable design policy"

$policyPath =
  Join-Path $repoRoot "design\design-policy.json"

$policy = @'
{
  "version": 1,
  "principles": {
    "childWellbeingFirst": true,
    "lowSensoryLoadDefault": true,
    "noBehaviouralDarkPatterns": true,
    "reducedMotionRequired": true,
    "accessibleFocusRequired": true,
    "originalVisualAssetsRequired": true
  },
  "learner": {
    "minimumTouchTargetPx": 56,
    "maximumPrimaryChoicesVisible": 6,
    "readingDensity": "very-low",
    "motion": "minimal"
  },
  "parent": {
    "minimumTouchTargetPx": 44,
    "readingDensity": "normal",
    "motion": "standard"
  },
  "forbiddenPatterns": [
    "flashing-reward",
    "streak-pressure",
    "loss-aversion",
    "countdown-pressure",
    "infinite-scroll",
    "behavioural-advertising",
    "forced-autoplay"
  ]
}
'@

Write-Utf8NoBom `
  -Path $policyPath `
  -Content $policy


$designToolRoot =
  Join-Path $repoRoot "tools\design"

New-Item `
  -ItemType Directory `
  -Force `
  -Path $designToolRoot `
  | Out-Null


$validator = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const repoRoot =
  process.cwd();

const policy =
  JSON.parse(
    fs.readFileSync(
      path.join(
        repoRoot,
        "design",
        "design-policy.json"
      ),
      "utf8"
    )
  );


const failures =
  [];


function fail(
  message
) {
  failures.push(
    message
  );

  console.error(
    `DESIGN POLICY ERROR: ${message}`
  );
}


if (
  policy.principles
    ?.childWellbeingFirst !==
  true
) {
  fail(
    "childWellbeingFirst must remain true"
  );
}


if (
  policy.principles
    ?.noBehaviouralDarkPatterns !==
  true
) {
  fail(
    "noBehaviouralDarkPatterns must remain true"
  );
}


if (
  policy.principles
    ?.reducedMotionRequired !==
  true
) {
  fail(
    "reducedMotionRequired must remain true"
  );
}


if (
  Number(
    policy.learner
      ?.minimumTouchTargetPx
  ) <
  44
) {
  fail(
    "learner minimum touch target must be at least 44px"
  );
}


if (
  Number(
    policy.parent
      ?.minimumTouchTargetPx
  ) <
  44
) {
  fail(
    "parent minimum touch target must be at least 44px"
  );
}


const requiredForbidden =
  [
    "streak-pressure",
    "loss-aversion",
    "countdown-pressure",
    "infinite-scroll",
    "behavioural-advertising"
  ];


for (
  const item
  of requiredForbidden
) {
  if (
    !policy.forbiddenPatterns
      ?.includes(
        item
      )
  ) {
    fail(
      `required forbidden pattern missing: ${item}`
    );
  }
}


if (
  failures.length >
  0
) {
  process.exit(1);
}


console.log(
  "DESIGN POLICY VALIDATION: PASS"
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $designToolRoot "validate.mjs") `
  -Content $validator


# ============================================================
# 8. Design documentation.
# ============================================================

Write-Step "Writing design-system specification"

$designDoc = @'
# HIBEYA Akal Budi — Design System Foundation

## Purpose

The design system separates visual decisions from feature implementation.

Learner and parent experiences share a brand language but use different interaction contracts.

## Learner design principles

- very low reading density;
- large touch targets;
- calm visual hierarchy;
- low sensory load;
- minimal motion;
- no time pressure;
- no streak pressure;
- no infinite-scroll pattern;
- no forced autoplay;
- no behavioural advertising;
- mistakes receive gentle, non-punitive feedback.

## Parent design principles

- higher information density than learner UI;
- clear progress interpretation;
- explicit destructive-action confirmation;
- accessible focus states;
- no vanity metrics that encourage unhealthy child engagement.

## Semantic tokens

Application code should migrate toward semantic tokens instead of raw colours.

Example:

```text
surface-card
text-primary
feedback-success-surface
feedback-gentle-text
focus-ring
```

Do not build product identity around arbitrary Tailwind colour names.

## Illustration boundary

Core learner artwork must eventually be sourced through the HIBEYA asset/provenance pipeline.

Stock imagery, emoji and generated placeholders are not the final commercial visual system.

Phase 006A does not replace current assets yet.

## Motion

Motion supports comprehension only.

Acceptable examples:

- gentle selection transition;
- short state change;
- low-intensity progress acknowledgement.

Not acceptable:

- flashing;
- celebratory loops;
- forced confetti;
- engagement-driven autoplay;
- reward escalation.

## Future phases

006B:
Shared React primitives and Storybook.

006C:
Application token adoption and accessibility regression.

007:
Original illustration system and provenance pipeline.
'@

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot "DESIGN_SYSTEM.md") `
  -Content $designDoc


# ============================================================
# 9. Root package automation commands.
# ============================================================

Write-Step "Adding design automation commands"

$packagePath =
  Join-Path $repoRoot "package.json"

Backup-File $packagePath

$rootPackage =
  Get-Content $packagePath -Raw |
  ConvertFrom-Json

if (-not $rootPackage.scripts) {
  $rootPackage |
    Add-Member `
      -NotePropertyName "scripts" `
      -NotePropertyValue ([pscustomobject]@{})
}

$rootPackage.scripts |
  Add-Member `
    -NotePropertyName "design:validate" `
    -NotePropertyValue "node tools/design/validate.mjs" `
    -Force

$rootPackageText =
  $rootPackage |
  ConvertTo-Json -Depth 100

Write-Utf8NoBom `
  -Path $packagePath `
  -Content $rootPackageText


# ============================================================
# 10. Lockfile + quality gates.
# ============================================================

Invoke-Native `
  -Name "Workspace lockfile refresh" `
  -Command "pnpm install --lockfile-only"

Invoke-Native `
  -Name "Design policy validation" `
  -Command "pnpm design:validate"

Invoke-Native `
  -Name "Curriculum validation" `
  -Command "pnpm curriculum:validate"

Invoke-Native `
  -Name "Curriculum source validation" `
  -Command "pnpm curriculum:sources:validate"

Invoke-Native `
  -Name "Content compiler check" `
  -Command "pnpm content:check"

Invoke-Native `
  -Name "Typecheck" `
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
  -Name "Supabase dry-run" `
  -Command "pnpm supabase db push --dry-run"

Invoke-Native `
  -Name "Git whitespace check" `
  -Command "git diff --check"


if ($Commit) {
  Invoke-Native `
    -Name "Git stage" `
    -Command "git add packages/design-system design tools/design DESIGN_SYSTEM.md package.json pnpm-lock.yaml"

  Invoke-Native `
    -Name "Git commit" `
    -Command 'git commit -m "feat: add design system foundation"'
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006A: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Phase 006B Shared React Primitives + Storybook." -ForegroundColor Cyan
