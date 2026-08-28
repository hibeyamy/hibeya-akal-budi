param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$backupRoot = Join-Path $repoRoot "tools\dev\backups"
$assetRoot = Join-Path $repoRoot "assets"
$manifestRoot = Join-Path $assetRoot "manifests"
$toolRoot = Join-Path $repoRoot "tools\assets"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
New-Item -ItemType Directory -Force -Path $manifestRoot | Out-Null
New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$sessionLog = Join-Path $logsRoot "phase007a-$runId.log"

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
  $stdout = Join-Path $logsRoot "phase007a-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase007a-$timestamp-err.log"

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

  if ($outText) {
    Write-Host $outText
    Add-Content -Path $sessionLog -Value $outText -Encoding UTF8
  }

  if ($errText) {
    Write-Host $errText
    Add-Content -Path $sessionLog -Value $errText -Encoding UTF8
  }

  if ($process.ExitCode -ne 0) {
    $diagnostic = Join-Path $logsRoot "FAILED-phase007a-$timestamp-$($Name.Replace(' ','-')).log"

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
PHASE 007A FAILED

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
  Write-Host "PHASE 007A: FAILED" -ForegroundColor Red
  Write-Host "Diagnostic: $sessionLog" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007A" -ForegroundColor Cyan
Write-Host "Original Asset Provenance Foundation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

# ============================================================
# 1. Asset policy
# ============================================================

Log ""
Log "==> Creating commercial asset policy"

$policy = @'
{
  "version": 1,
  "principles": {
    "originalityFirst": true,
    "commercialRightsRequired": true,
    "provenanceRequired": true,
    "childSafetyReviewRequired": true,
    "culturalReviewRequiredWhenRelevant": true,
    "noUntrackedStockAssets": true,
    "noUnreviewedThirdPartyCharacters": true,
    "noTrademarkImitation": true
  },
  "productionFormats": [
    "svg",
    "png",
    "webp"
  ],
  "prototypeFormats": [
    "emoji",
    "svg",
    "png",
    "webp"
  ],
  "allowedSourceTypes": [
    "original-internal",
    "original-ai-assisted",
    "commissioned-original",
    "unicode-emoji",
    "legacy-placeholder"
  ],
  "commercialSourceTypes": [
    "original-internal",
    "original-ai-assisted",
    "commissioned-original"
  ],
  "requiredProductionChecks": [
    "commercialRightsConfirmed",
    "originalityReviewed",
    "childSafetyReviewed"
  ]
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $assetRoot "provenance-policy.json") `
  -Content $policy

# ============================================================
# 2. Directory architecture for future source/master/export files
# ============================================================

Log ""
Log "==> Creating scalable asset directories"

foreach ($dir in @(
  "source",
  "masters",
  "exports",
  "review"
)) {
  $path = Join-Path $assetRoot $dir
  New-Item -ItemType Directory -Force -Path $path | Out-Null

  $keep = Join-Path $path ".gitkeep"
  if (-not (Test-Path $keep)) {
    Write-Utf8NoBom -Path $keep -Content ""
  }
}

Log "PASS: asset directories ready"

# ============================================================
# 3. Bootstrap existing registry into provenance manifests.
#    Existing emoji/legacy assets remain prototype only.
# ============================================================

Log ""
Log "==> Installing provenance bootstrapper"

$bootstrap = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const registryPath =
  path.join(
    root,
    "packages",
    "assets",
    "src",
    "index.ts"
  );

const manifestRoot =
  path.join(
    root,
    "assets",
    "manifests"
  );

if (!fs.existsSync(registryPath)) {
  console.error(
    `Asset registry missing: ${registryPath}`
  );

  process.exit(1);
}

fs.mkdirSync(
  manifestRoot,
  {
    recursive: true
  }
);

const source =
  fs.readFileSync(
    registryPath,
    "utf8"
  );

const pattern =
  /"([^"]+)"\s*:\s*\{[\s\S]*?\bid\s*:\s*"([^"]+)"[\s\S]*?\btype\s*:\s*"(emoji|image)"[\s\S]*?\bvalue\s*:\s*"([^"]*)"/g;

const found =
  new Map();

for (
  const match
  of source.matchAll(
    pattern
  )
) {
  const objectKey =
    match[1];

  const id =
    match[2];

  const type =
    match[3];

  const value =
    match[4];

  if (
    objectKey !== id
  ) {
    console.error(
      `Registry key/id mismatch: ${objectKey} != ${id}`
    );

    process.exit(1);
  }

  found.set(
    id,
    {
      id,
      type,
      value
    }
  );
}

if (
  found.size === 0
) {
  console.error(
    "No asset definitions could be detected in packages/assets/src/index.ts"
  );

  process.exit(1);
}

let created = 0;
let existing = 0;

for (
  const asset
  of found.values()
) {
  const target =
    path.join(
      manifestRoot,
      `${asset.id}.json`
    );

  if (
    fs.existsSync(
      target
    )
  ) {
    existing += 1;
    continue;
  }

  const manifest = {
    schemaVersion:
      1,

    id:
      asset.id,

    status:
      "prototype",

    role:
      "learner-core",

    currentRepresentation:
      asset.type ===
      "emoji"
        ? "emoji"
        : "legacy-image",

    sourceType:
      asset.type ===
      "emoji"
        ? "unicode-emoji"
        : "legacy-placeholder",

    creator:
      "legacy-system",

    sourceFile:
      "packages/assets/src/index.ts",

    sourceValue:
      asset.value,

    commercialRightsConfirmed:
      false,

    originalityReviewed:
      false,

    culturalReviewRequired:
      false,

    culturalReviewed:
      false,

    childSafetyReviewed:
      false,

    commercialReady:
      false,

    replacementRequiredForCommercialRelease:
      true,

    notes:
      "Automatically classified as a prototype asset during Phase 007A. Replace through the HIBEYA original asset pipeline before commercial release."
  };

  fs.writeFileSync(
    target,
    JSON.stringify(
      manifest,
      null,
      2
    ) + "\n",
    "utf8"
  );

  created += 1;
}

console.log(
  `ASSET BOOTSTRAP: ${found.size} registry assets; ${created} manifests created; ${existing} preserved`
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $toolRoot "bootstrap-manifests.mjs") `
  -Content $bootstrap

# ============================================================
# 4. Provenance validator
# ============================================================

Log ""
Log "==> Installing provenance validator"

$validator = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const policyPath =
  path.join(
    root,
    "assets",
    "provenance-policy.json"
  );

const manifestRoot =
  path.join(
    root,
    "assets",
    "manifests"
  );

const policy =
  JSON.parse(
    fs.readFileSync(
      policyPath,
      "utf8"
    )
  );

const failures = [];

function fail(message) {
  failures.push(message);
  console.error(
    `ASSET PROVENANCE ERROR: ${message}`
  );
}

const files =
  fs.readdirSync(
    manifestRoot
  )
    .filter(
      file =>
        file.endsWith(
          ".json"
        )
    );

if (
  files.length === 0
) {
  fail(
    "No asset provenance manifests exist"
  );
}

const seen =
  new Set();

for (
  const file
  of files
) {
  const full =
    path.join(
      manifestRoot,
      file
    );

  let manifest;

  try {
    manifest =
      JSON.parse(
        fs.readFileSync(
          full,
          "utf8"
        )
      );
  }
  catch (error) {
    fail(
      `${file}: invalid JSON`
    );

    continue;
  }

  const required = [
    "schemaVersion",
    "id",
    "status",
    "role",
    "currentRepresentation",
    "sourceType",
    "creator",
    "sourceFile",
    "commercialRightsConfirmed",
    "originalityReviewed",
    "childSafetyReviewed",
    "commercialReady"
  ];

  for (
    const field
    of required
  ) {
    if (
      manifest[field] ===
      undefined ||
      manifest[field] ===
      null ||
      manifest[field] ===
      ""
    ) {
      fail(
        `${file}: missing ${field}`
      );
    }
  }

  if (
    seen.has(
      manifest.id
    )
  ) {
    fail(
      `${file}: duplicate asset id ${manifest.id}`
    );
  }

  seen.add(
    manifest.id
  );

  if (
    file !==
    `${manifest.id}.json`
  ) {
    fail(
      `${file}: filename must match asset id`
    );
  }

  if (
    !policy.allowedSourceTypes.includes(
      manifest.sourceType
    )
  ) {
    fail(
      `${file}: unsupported sourceType ${manifest.sourceType}`
    );
  }

  if (
    manifest.status ===
      "production" &&
    manifest.commercialReady !==
      true
  ) {
    fail(
      `${file}: production asset must be commercialReady`
    );
  }

  if (
    manifest.commercialReady ===
      true
  ) {
    for (
      const check
      of policy.requiredProductionChecks
    ) {
      if (
        manifest[check] !==
        true
      ) {
        fail(
          `${file}: commercial asset requires ${check}=true`
        );
      }
    }

    if (
      !policy.commercialSourceTypes.includes(
        manifest.sourceType
      )
    ) {
      fail(
        `${file}: source type is not approved for commercial release`
      );
    }

    if (
      manifest.culturalReviewRequired ===
        true &&
      manifest.culturalReviewed !==
        true
    ) {
      fail(
        `${file}: required cultural review is incomplete`
      );
    }
  }
}

if (
  failures.length > 0
) {
  process.exit(1);
}

console.log(
  `ASSET PROVENANCE VALIDATION: PASS (${files.length} manifests)`
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $toolRoot "validate-provenance.mjs") `
  -Content $validator

# ============================================================
# 5. Commercial readiness validator.
#    This is intentionally NOT a Phase 007A pass gate because
#    prototype emoji assets still need replacement.
# ============================================================

Log ""
Log "==> Installing commercial asset release gate"

$commercialValidator = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const manifestRoot =
  path.join(
    root,
    "assets",
    "manifests"
  );

const files =
  fs.readdirSync(
    manifestRoot
  )
    .filter(
      file =>
        file.endsWith(
          ".json"
        )
    );

const blocked = [];

for (
  const file
  of files
) {
  const manifest =
    JSON.parse(
      fs.readFileSync(
        path.join(
          manifestRoot,
          file
        ),
        "utf8"
      )
    );

  if (
    manifest.role ===
      "learner-core" &&
    manifest.commercialReady !==
      true
  ) {
    blocked.push(
      manifest.id
    );
  }
}

if (
  blocked.length > 0
) {
  console.error(
    "COMMERCIAL ASSET GATE: BLOCKED"
  );

  console.error(
    "Replace/review these learner-core assets before commercial release:"
  );

  for (
    const id
    of blocked
  ) {
    console.error(
      `- ${id}`
    );
  }

  process.exit(1);
}

console.log(
  "COMMERCIAL ASSET GATE: PASS"
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $toolRoot "validate-commercial.mjs") `
  -Content $commercialValidator

# ============================================================
# 6. Documentation
# ============================================================

Log ""
Log "==> Writing asset provenance specification"

$doc = @'
# HIBEYA Akal Budi — Original Asset & Provenance Standard

## Purpose

Every learner-facing production asset must have an auditable origin and explicit commercial-use status.

Phase 007A establishes the governance layer before large-scale illustration production starts.

## Core rule

A file being visually attractive does not make it commercially ready.

A production asset must be:

- original or commissioned for HIBEYA;
- commercially usable;
- traceable to a creator/source process;
- reviewed for originality;
- reviewed for child suitability;
- culturally reviewed when relevant;
- represented by a provenance manifest.

## Source types

Commercially approved:

- `original-internal`
- `original-ai-assisted`
- `commissioned-original`

Prototype only:

- `unicode-emoji`
- `legacy-placeholder`

Prototype assets may remain during development but block the later commercial asset release gate.

## Directory model

```text
assets/
├── manifests/       machine-readable provenance
├── source/          editable source material / working files
├── masters/         approved master artwork
├── exports/         runtime-ready SVG/PNG/WebP
└── review/          review notes and approval evidence
```

## Commercial gate

Normal provenance validation:

```powershell
pnpm assets:validate
```

Strict commercial-release check:

```powershell
pnpm assets:commercial:validate
```

The commercial gate is expected to remain blocked until the current prototype learner assets are replaced.

## AI-assisted artwork

AI-assisted artwork is permitted only when:

- the final composition is created specifically for HIBEYA;
- no request is made to imitate a living artist or protected character;
- prompts and source context do not intentionally reproduce third-party IP;
- the asset receives an originality review;
- commercial rights are confirmed for the production workflow;
- culturally sensitive Malaysian elements receive human review.

## Copyright boundary

Do not copy:

- worksheets;
- educational app artwork;
- children's characters;
- book illustrations;
- branded mascots;
- icon packs without a verified licence.

Reference material may inform general factual or cultural accuracy, but the final visual expression must be independently created.

## Current status after Phase 007A

Existing emoji/legacy learner assets are catalogued as prototypes.

They are deliberately **not** marked commercial-ready.

The next phases create the original HIBEYA illustration language and replacement asset production workflow.
'@

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot "ASSET_PROVENANCE.md") `
  -Content $doc

# ============================================================
# 7. Register scripts in root package.json using Node
# ============================================================

Log ""
Log "==> Registering asset automation commands"

$rootPackagePath =
  Join-Path `
    $repoRoot `
    "package.json"

$tempEditor =
  Join-Path `
    $env:TEMP `
    "akal-budi-phase007a-package-editor.cjs"

$editor = @'
const fs = require("fs");

const packagePath =
  process.argv[2];

const pkg =
  JSON.parse(
    fs.readFileSync(
      packagePath,
      "utf8"
    )
  );

pkg.scripts ??= {};

pkg.scripts["assets:bootstrap"] =
  "node tools/assets/bootstrap-manifests.mjs";

pkg.scripts["assets:validate"] =
  "node tools/assets/validate-provenance.mjs";

pkg.scripts["assets:commercial:validate"] =
  "node tools/assets/validate-commercial.mjs";

fs.writeFileSync(
  packagePath,
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
  throw "Could not register asset scripts."
}

Remove-Item `
  $tempEditor `
  -Force `
  -ErrorAction SilentlyContinue

Log "PASS: asset commands registered"

# ============================================================
# 8. Bootstrap + validation
# ============================================================

Invoke-Native `
  -Name "Bootstrap asset provenance" `
  -Command "pnpm assets:bootstrap"

Invoke-Native `
  -Name "Asset provenance validation" `
  -Command "pnpm assets:validate"

# ============================================================
# 9. Existing regression gates
# ============================================================

Invoke-Native `
  -Name "Design policy validation" `
  -Command "pnpm design:validate"

Invoke-Native `
  -Name "Design adoption validation" `
  -Command "pnpm design:apps:validate"

Invoke-Native `
  -Name "Content compiler check" `
  -Command "pnpm content:check"

Invoke-Native `
  -Name "Repository typecheck" `
  -Command "pnpm typecheck"

Invoke-Native `
  -Name "All tests" `
  -Command "pnpm test"

Invoke-Native `
  -Name "Production build" `
  -Command "pnpm build"

Invoke-Native `
  -Name "Accessibility regression" `
  -Command "pnpm qa:a11y"

Invoke-Native `
  -Name "Visual regression verification" `
  -Command "pnpm qa:visual"

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
# 10. Optional commit
# ============================================================

if ($Commit) {
  Invoke-Native `
    -Name "Stage Phase 007A" `
    -Command "git add assets tools/assets ASSET_PROVENANCE.md package.json"

  Invoke-Native `
    -Name "Commit Phase 007A" `
    -Command 'git commit -m "feat: add original asset provenance foundation"'
}

Log ""
Log "PHASE 007A: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007A: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Note: pnpm assets:commercial:validate is expected to remain BLOCKED until prototype learner assets are replaced." -ForegroundColor Yellow
Write-Host "Next: Phase 007B HIBEYA Illustration Language + Production Asset Workflow." -ForegroundColor Cyan
Write-Host "Log: $sessionLog" -ForegroundColor DarkGray
