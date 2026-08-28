param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$design = Join-Path $root "design\illustration"
$tools = Join-Path $root "tools\assets"

New-Item -ItemType Directory -Force -Path $logs,$design,$tools | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007b-$runId.log"

function WriteText([string]$Path,[string]$Content) {
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path,$Content.TrimEnd()+"`n",[Text.UTF8Encoding]::new($false))
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`n$Command" -Encoding UTF8
  $p = Start-Process "cmd.exe" -ArgumentList @("/d","/s","/c",$Command) -WorkingDirectory $root -NoNewWindow -Wait -PassThru
  if ($p.ExitCode -ne 0) { throw "$Name failed with exit code $($p.ExitCode). Log: $log" }
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 007B: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007B" -ForegroundColor Cyan
Write-Host "Illustration Language + Production Workflow" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# Machine-readable illustration system
# ------------------------------------------------------------------

$spec = @'
{
  "schemaVersion": 1,
  "system": "hibeya-akal-budi-illustration",
  "principles": [
    "child-readable",
    "calm-not-overstimulating",
    "malaysian-contextual",
    "originality-first",
    "accessible",
    "age-aware",
    "curriculum-extensible"
  ],
  "ageBands": {
    "4-5": {
      "detail": "low",
      "shapeComplexity": "simple",
      "backgroundDensity": "minimal",
      "primaryObjectCount": [1, 4],
      "touchTargetPx": 56
    },
    "6-7": {
      "detail": "medium-low",
      "shapeComplexity": "simple-to-moderate",
      "backgroundDensity": "light",
      "primaryObjectCount": [1, 6],
      "touchTargetPx": 52
    },
    "8-9": {
      "detail": "medium",
      "shapeComplexity": "moderate",
      "backgroundDensity": "moderate",
      "primaryObjectCount": [1, 8],
      "touchTargetPx": 48
    }
  },
  "geometry": {
    "cornerLanguage": "soft-rounded",
    "outline": "consistent-friendly",
    "silhouettePriority": true,
    "microDetail": "restricted",
    "minimumSeparationPx": 8
  },
  "characters": {
    "humanDiversity": "malaysian-inclusive",
    "expression": "clear-positive-neutral",
    "bodyLanguage": "readable",
    "stereotypesForbidden": true,
    "protectedCharactersForbidden": true,
    "celebrityLikenessForbidden": true
  },
  "culture": {
    "malaysianElementsAllowed": true,
    "contextualAccuracyRequired": true,
    "religiousElementsRequireReview": true,
    "traditionalScriptsRequireSourceValidation": true,
    "avoidTokenism": true
  },
  "learning": {
    "decorativeCompetitionWithTask": "forbidden",
    "correctAnswerMustNotBeVisuallyLeaked": true,
    "instructionalHierarchyRequired": true,
    "colourOnlyMeaningForbidden": true
  },
  "production": {
    "preferredMaster": "svg",
    "runtimeFormats": ["svg", "webp", "png"],
    "transparentBackgroundPreferredForObjects": true,
    "rasterScaleFactors": [1, 2],
    "naming": "<asset-id>--<variant>--v<major>",
    "manifestRequired": true
  }
}
'@
WriteText (Join-Path $design "illustration-system.json") $spec

$style = @'
# HIBEYA Akal Budi Illustration Language

## Visual objective

The learner interface should look recognisably HIBEYA without depending on fashionable illustration trends, third-party characters, or generic stock artwork.

The visual language is **clear, calm, playful and Malaysian-contextual**. Educational comprehension takes precedence over decoration.

## 1. Shape language

- Prefer simple, recognisable silhouettes.
- Use soft-rounded geometry for learner-facing objects.
- Avoid excessive micro-detail, especially for ages 4–7.
- Preserve enough negative space to distinguish objects on small screens.
- Do not use visual complexity merely to make a page look more premium.

## 2. Age adaptation

### Ages 4–5
Large objects, minimal backgrounds, very obvious silhouettes and low visual density.

### Ages 6–7
Slightly richer scenes while retaining strong object separation and simple composition.

### Ages 8–9
Moderate detail is permitted when it supports subject comprehension.

The same curriculum concept may therefore use different visual density by learner age.

## 3. Malaysian context

Local context should be meaningful rather than decorative. Examples include flora, food, clothing, architecture, games, landscapes and everyday objects.

Accuracy matters. Traditional, religious or script-related representations require appropriate source validation and human review.

Do not reduce Malaysian identity to repeated flags, landmarks or stereotypical motifs.

## 4. Characters

Characters must be independently designed for HIBEYA.

Forbidden:
- copies or close adaptations of protected children's characters;
- celebrity likenesses;
- prompts requesting another living artist's distinctive style;
- racial, cultural, religious or gender stereotypes.

Human characters should support Malaysian diversity naturally across the library rather than forcing every individual illustration to represent every demographic.

## 5. Educational hierarchy

The activity objective is always visually dominant.

Illustration must not:
- reveal the correct answer unintentionally;
- compete with instructions;
- rely on colour alone to communicate meaning;
- create unnecessary cognitive load.

## 6. Originality rule

Production assets must pass the Phase 007A provenance system.

AI-assisted generation is an input to the production process, not automatic approval. A generated image still requires:
1. originality review;
2. rights confirmation;
3. child-suitability review;
4. cultural review when applicable;
5. provenance registration.

## 7. Asset families

The system supports:
- learning objects;
- Malaysian contextual objects;
- environments;
- human characters;
- friendly non-branded creatures;
- rewards and feedback;
- curriculum-specific symbols;
- Jawi and other script-supporting educational graphics.

Script glyphs themselves should come from properly licensed fonts or validated vector sources rather than being hallucinated inside generated artwork.

## 8. Runtime quality

SVG is preferred for scalable object artwork. WebP/PNG may be used where raster artwork is appropriate.

Every exported asset should remain readable on mobile, tablet and desktop. Production assets should be tested in actual activity layouts, not approved in isolation.
'@
WriteText (Join-Path $design "STYLE_BIBLE.md") $style

$workflow = @'
# Illustration Production Workflow

## Pipeline

```text
Learning requirement
      ↓
Asset brief
      ↓
Original creation / AI-assisted draft
      ↓
Human visual review
      ↓
Cultural / curriculum review where required
      ↓
Master artwork
      ↓
Optimised exports
      ↓
Provenance manifest
      ↓
Automated validation
      ↓
Activity integration
      ↓
Accessibility + visual regression
      ↓
Commercial release gate
```

## Asset brief minimum fields

- asset ID
- curriculum purpose
- learner age band
- visual subject
- interaction role
- Malaysian context, if any
- cultural review requirement
- required variants
- master format
- runtime formats

## Approval states

`draft` → `review` → `approved-master` → `production`

An asset must not enter `production` solely because an image file exists.

## Scaling principle

New curricula such as Jawi, mathematics, science or language learning add asset families to this same pipeline. They do not create separate unmanaged illustration systems.
'@
WriteText (Join-Path $design "PRODUCTION_WORKFLOW.md") $workflow

$template = @'
{
  "schemaVersion": 1,
  "assetId": "replace-me",
  "curriculumPurpose": "replace-me",
  "ageBands": ["4-5"],
  "subject": "replace-me",
  "interactionRole": "learning-object",
  "malaysianContext": [],
  "culturalReviewRequired": false,
  "variants": ["default"],
  "masterFormat": "svg",
  "runtimeFormats": ["svg", "webp"],
  "status": "draft"
}
'@
WriteText (Join-Path $design "asset-brief.template.json") $template

# ------------------------------------------------------------------
# Validator
# ------------------------------------------------------------------

$validator = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const base = path.join(root, "design", "illustration");

const required = [
  "illustration-system.json",
  "STYLE_BIBLE.md",
  "PRODUCTION_WORKFLOW.md",
  "asset-brief.template.json"
];

const failures = [];

for (const file of required) {
  const target = path.join(base, file);
  if (!fs.existsSync(target)) failures.push(`Missing ${file}`);
}

let spec;
try {
  spec = JSON.parse(
    fs.readFileSync(path.join(base, "illustration-system.json"), "utf8")
  );
} catch {
  failures.push("illustration-system.json is invalid JSON");
}

if (spec) {
  if (spec.schemaVersion !== 1) failures.push("Unsupported illustration schemaVersion");
  if (!spec.ageBands?.["4-5"]) failures.push("Missing age band 4-5");
  if (!spec.ageBands?.["6-7"]) failures.push("Missing age band 6-7");
  if (!spec.ageBands?.["8-9"]) failures.push("Missing age band 8-9");
  if (spec.production?.preferredMaster !== "svg") failures.push("Preferred master must be svg");
  if (spec.learning?.colourOnlyMeaningForbidden !== true) failures.push("Colour-only meaning policy must be enabled");
  if (spec.characters?.protectedCharactersForbidden !== true) failures.push("Protected-character policy must be enabled");
}

let brief;
try {
  brief = JSON.parse(
    fs.readFileSync(path.join(base, "asset-brief.template.json"), "utf8")
  );
} catch {
  failures.push("asset-brief.template.json is invalid JSON");
}

if (brief) {
  for (const key of [
    "assetId",
    "curriculumPurpose",
    "ageBands",
    "subject",
    "interactionRole",
    "variants",
    "masterFormat",
    "runtimeFormats",
    "status"
  ]) {
    if (brief[key] === undefined) failures.push(`Asset brief missing ${key}`);
  }
}

if (failures.length) {
  for (const failure of failures) console.error(`ILLUSTRATION SYSTEM ERROR: ${failure}`);
  process.exit(1);
}

console.log("ILLUSTRATION SYSTEM VALIDATION: PASS");
'@
WriteText (Join-Path $tools "validate-illustration-system.mjs") $validator

# ------------------------------------------------------------------
# Register command safely with Node.
# ------------------------------------------------------------------

$editor = Join-Path $env:TEMP "hibeya-phase007b-package.cjs"
WriteText $editor @'
const fs = require("fs");
const p = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(p, "utf8"));
pkg.scripts ??= {};
pkg.scripts["illustration:validate"] =
  "node tools/assets/validate-illustration-system.mjs";
fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n");
'@

& node $editor (Join-Path $root "package.json")
if ($LASTEXITCODE -ne 0) { throw "package.json update failed" }
Remove-Item $editor -Force -ErrorAction SilentlyContinue

Run "Illustration system validation" "pnpm illustration:validate"
Run "Asset provenance validation" "pnpm assets:validate"
Run "Design policy validation" "pnpm design:validate"
Run "Design adoption validation" "pnpm design:apps:validate"
Run "Content compiler check" "pnpm content:check"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression verification" "pnpm qa:visual"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Curriculum source validation" "pnpm curriculum:sources:validate"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run "Stage Phase 007B" "git add design/illustration tools/assets/validate-illustration-system.mjs package.json"
  Run "Commit Phase 007B" 'git commit -m "feat: define Hibeya illustration production system"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007B: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Next: Phase 007C original production asset pipeline." -ForegroundColor Cyan
