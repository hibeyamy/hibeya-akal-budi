param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backupRoot = Join-Path $root "tools\dev\backups"
$masters = Join-Path $root "assets\masters"
$exports = Join-Path $root "assets\exports"
$runtime = Join-Path $root "packages\assets\src\generated"
$tools = Join-Path $root "tools\assets"

New-Item -ItemType Directory -Force -Path $logs,$backupRoot,$masters,$exports,$runtime,$tools | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007d-$runId.log"

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
  Copy-Item $Path (Join-Path $backupRoot "$runId-$safe") -Force
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`n$Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase007d-$stamp-out.log"
  $err = Join-Path $logs "phase007d-$stamp-err.log"

  $p = Start-Process "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err `
    -NoNewWindow `
    -Wait `
    -PassThru

  $o = if (Test-Path $out) { Get-Content $out -Raw } else { "" }
  $e = if (Test-Path $err) { Get-Content $err -Raw } else { "" }

  if ($o) { Write-Host $o; Add-Content $log $o -Encoding UTF8 }
  if ($e) { Write-Host $e; Add-Content $log $e -Encoding UTF8 }

  if ($p.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase007d-$stamp-$($Name.Replace(' ','-')).log"
    WriteText $diag "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$o`n`nSTDERR:`n$e"
    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 007D: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007D" -ForegroundColor Cyan
Write-Host "First Original Learner Asset Batch" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# 1. Deterministic original SVG masters
# ------------------------------------------------------------------

$appleRed = @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 320" role="img" aria-labelledby="title desc">
  <title id="title">Red apple</title>
  <desc id="desc">Original HIBEYA illustration of a simple red apple with one green leaf.</desc>
  <g fill="none" stroke="#23333F" stroke-width="10" stroke-linecap="round" stroke-linejoin="round">
    <path d="M162 89c-8-27 4-47 25-59" />
    <path d="M174 62c25-17 51-12 66 7-23 16-47 17-66-7Z" fill="#69A84F"/>
    <path d="M159 103c-27-31-77-25-98 10-25 42-10 110 31 150 22 22 44 31 67 18 23 13 45 4 67-18 41-40 56-108 31-150-21-35-71-41-98-10Z" fill="#E85A4F"/>
    <path d="M105 133c12-17 30-24 46-21" stroke="#F8B2A9" stroke-width="9"/>
  </g>
</svg>
'@

$appleGreen = @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 320" role="img" aria-labelledby="title desc">
  <title id="title">Green apple</title>
  <desc id="desc">Original HIBEYA illustration of a simple green apple with one leaf.</desc>
  <g fill="none" stroke="#23333F" stroke-width="10" stroke-linecap="round" stroke-linejoin="round">
    <path d="M162 89c-8-27 4-47 25-59" />
    <path d="M174 62c25-17 51-12 66 7-23 16-47 17-66-7Z" fill="#4F8D45"/>
    <path d="M159 103c-27-31-77-25-98 10-25 42-10 110 31 150 22 22 44 31 67 18 23 13 45 4 67-18 41-40 56-108 31-150-21-35-71-41-98-10Z" fill="#8BCB68"/>
    <path d="M105 133c12-17 30-24 46-21" stroke="#CDEBAF" stroke-width="9"/>
  </g>
</svg>
'@

$bananaYellow = @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 320" role="img" aria-labelledby="title desc">
  <title id="title">Yellow banana</title>
  <desc id="desc">Original HIBEYA illustration of one simple curved yellow banana.</desc>
  <g fill="none" stroke="#23333F" stroke-width="10" stroke-linecap="round" stroke-linejoin="round">
    <path d="M78 86c40 88 93 122 177 97-26 50-78 82-132 67-54-15-86-68-75-126 4-20 13-33 30-38Z" fill="#F4C84A"/>
    <path d="M76 84 62 64" />
    <path d="M255 183 272 172" />
    <path d="M88 111c32 63 76 88 136 78" stroke="#FFE48A" stroke-width="9"/>
  </g>
</svg>
'@

$batch = @{
  "apple-red" = $appleRed
  "apple-green" = $appleGreen
  "banana-yellow" = $bananaYellow
}

foreach ($id in $batch.Keys) {
  WriteText (Join-Path $masters "$id.svg") $batch[$id]
  WriteText (Join-Path $exports "$id.svg") $batch[$id]
  WriteText (Join-Path $runtime "$id.svg") $batch[$id]
}

Write-Host "PASS: 3 deterministic original SVG masters created" -ForegroundColor Green

# ------------------------------------------------------------------
# 2. Runtime commercial override map
# ------------------------------------------------------------------

$commercialTs = @'
export interface CommercialAssetOverride {
  id: string;
  type: "image";
  value: string;
  alt: {
    ms: string;
    en: string;
  };
}

export const commercialAssetOverrides:
  Record<string, CommercialAssetOverride> = {
    "apple-red": {
      id: "apple-red",
      type: "image",
      value: new URL(
        "./generated/apple-red.svg",
        import.meta.url
      ).href,
      alt: {
        ms: "Epal merah",
        en: "Red apple"
      }
    },

    "apple-green": {
      id: "apple-green",
      type: "image",
      value: new URL(
        "./generated/apple-green.svg",
        import.meta.url
      ).href,
      alt: {
        ms: "Epal hijau",
        en: "Green apple"
      }
    },

    "banana-yellow": {
      id: "banana-yellow",
      type: "image",
      value: new URL(
        "./generated/banana-yellow.svg",
        import.meta.url
      ).href,
      alt: {
        ms: "Pisang kuning",
        en: "Yellow banana"
      }
    }
  };
'@
WriteText (Join-Path $root "packages\assets\src\commercial.ts") $commercialTs

# ------------------------------------------------------------------
# 3. Patch asset registry without rewriting unknown assets.
# ------------------------------------------------------------------

$assetIndex = Join-Path $root "packages\assets\src\index.ts"
if (-not (Test-Path $assetIndex)) { throw "Asset registry missing: $assetIndex" }
Backup $assetIndex

$patchAssets = Join-Path $env:TEMP "hibeya-phase007d-patch-assets.cjs"
WriteText $patchAssets @'
const fs = require("fs");
const p = process.argv[2];
let s = fs.readFileSync(p, "utf8");

const importLine =
  'import { commercialAssetOverrides } from "./commercial";\n\n';

if (!s.includes('from "./commercial"')) {
  s = importLine + s;
}

const old =
`export function getAsset(assetId: string): AssetDefinition {
  const asset = assets[assetId];

  if (!asset) {
    throw new Error(\`Unknown asset: \${assetId}\`);
  }

  return asset;
}`;

const replacement =
`export function getAsset(assetId: string): AssetDefinition {
  const asset =
    commercialAssetOverrides[assetId] ??
    assets[assetId];

  if (!asset) {
    throw new Error(\`Unknown asset: \${assetId}\`);
  }

  return asset;
}`;

if (s.includes(old)) {
  s = s.replace(old, replacement);
} else if (!s.includes("commercialAssetOverrides[assetId]")) {
  console.error("Could not safely patch getAsset()");
  process.exit(2);
}

fs.writeFileSync(p, s.replace(/\r\n/g,"\n"), "utf8");
'@

& node $patchAssets $assetIndex
if ($LASTEXITCODE -ne 0) { throw "Asset registry patch failed." }
Remove-Item $patchAssets -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------------
# 4. Patch ActivityPlayer to render images while preserving emoji fallback.
# ------------------------------------------------------------------

$player = Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"
if (-not (Test-Path $player)) { throw "ActivityPlayer missing: $player" }
Backup $player

$patchPlayer = Join-Path $env:TEMP "hibeya-phase007d-patch-player.cjs"
WriteText $patchPlayer @'
const fs = require("fs");
const p = process.argv[2];
let s = fs.readFileSync(p, "utf8");

if (/asset\.type\s*===\s*['"]image['"]/.test(s)) {
  process.exit(0);
}

const old =
`                <span
                  aria-hidden="true"
                  className="text-7xl sm:text-8xl"
                >
                  {asset.value}
                </span>`;

const replacement =
`                {asset.type === "image" ? (
                  <img
                    src={asset.value}
                    alt=""
                    aria-hidden="true"
                    draggable={false}
                    className="h-28 w-28 select-none object-contain sm:h-32 sm:w-32"
                  />
                ) : (
                  <span
                    aria-hidden="true"
                    className="text-7xl sm:text-8xl"
                  >
                    {asset.value}
                  </span>
                )}`;

if (!s.includes(old)) {
  console.error("Could not safely locate legacy asset rendering block.");
  process.exit(2);
}

s = s.replace(old, replacement);
fs.writeFileSync(p, s.replace(/\r\n/g,"\n"), "utf8");
'@

& node $patchPlayer $player
if ($LASTEXITCODE -ne 0) { throw "ActivityPlayer image-render patch failed." }
Remove-Item $patchPlayer -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------------
# 5. Update only production-method/source metadata.
#    Keep human approval flags false until visual review.
# ------------------------------------------------------------------

$prepareReview = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow"
];

for (const id of ids) {
  const manifestPath =
    path.join(root, "assets", "manifests", `${id}.json`);

  if (!fs.existsSync(manifestPath)) {
    console.error(`Missing provenance manifest: ${id}`);
    process.exit(1);
  }

  const m =
    JSON.parse(
      fs.readFileSync(
        manifestPath,
        "utf8"
      )
    );

  m.status =
    "review";

  m.currentRepresentation =
    "svg";

  m.sourceType =
    "original-internal";

  m.creator =
    "HIBEYA deterministic vector production";

  m.sourceFile =
    `assets/masters/${id}.svg`;

  m.sourceValue =
    null;

  m.commercialRightsConfirmed =
    false;

  m.originalityReviewed =
    false;

  m.childSafetyReviewed =
    false;

  m.commercialReady =
    false;

  m.replacementRequiredForCommercialRelease =
    true;

  m.notes =
    "Original HIBEYA SVG candidate created in Phase 007D. Human visual/originality/rights/child-safety review is still required before commercial approval.";

  fs.writeFileSync(
    manifestPath,
    JSON.stringify(
      m,
      null,
      2
    ) + "\n",
    "utf8"
  );

  const briefPath =
    path.join(
      root,
      "assets",
      "briefs",
      `${id}.json`
    );

  if (
    fs.existsSync(
      briefPath
    )
  ) {
    const b =
      JSON.parse(
        fs.readFileSync(
          briefPath,
          "utf8"
        )
      );

    b.productionMethod =
      "original-internal";

    b.status =
      "review";

    fs.writeFileSync(
      briefPath,
      JSON.stringify(
        b,
        null,
        2
      ) + "\n",
      "utf8"
    );
  }
}

console.log(
  "FIRST ASSET BATCH: review candidates prepared"
);
'@
WriteText (Join-Path $tools "prepare-first-batch-review.mjs") $prepareReview

# ------------------------------------------------------------------
# 6. Batch validator: hashes must match master/export/runtime.
# ------------------------------------------------------------------

$batchValidator = @'
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow"
];

const failures = [];

function hash(file) {
  return crypto
    .createHash("sha256")
    .update(fs.readFileSync(file))
    .digest("hex");
}

for (const id of ids) {
  const master =
    path.join(root, "assets", "masters", `${id}.svg`);

  const exported =
    path.join(root, "assets", "exports", `${id}.svg`);

  const runtime =
    path.join(root, "packages", "assets", "src", "generated", `${id}.svg`);

  const manifest =
    path.join(root, "assets", "manifests", `${id}.json`);

  for (const file of [master, exported, runtime, manifest]) {
    if (!fs.existsSync(file)) {
      failures.push(`${id}: missing ${path.relative(root,file)}`);
    }
  }

  if (
    fs.existsSync(master) &&
    fs.existsSync(exported) &&
    fs.existsSync(runtime)
  ) {
    const hashes = [
      hash(master),
      hash(exported),
      hash(runtime)
    ];

    if (
      new Set(hashes).size !==
      1
    ) {
      failures.push(`${id}: master/export/runtime hashes differ`);
    }
  }

  if (fs.existsSync(manifest)) {
    const m =
      JSON.parse(
        fs.readFileSync(
          manifest,
          "utf8"
        )
      );

    if (m.sourceType !== "original-internal") {
      failures.push(`${id}: sourceType must be original-internal`);
    }

    if (m.status !== "review") {
      failures.push(`${id}: expected review status before human approval`);
    }

    if (m.commercialReady !== false) {
      failures.push(`${id}: must not self-approve commercialReady`);
    }
  }
}

if (failures.length) {
  for (const failure of failures) {
    console.error(`FIRST BATCH ERROR: ${failure}`);
  }

  process.exit(1);
}

console.log(
  "FIRST ORIGINAL ASSET BATCH: PASS (3 review candidates)"
);
'@
WriteText (Join-Path $tools "validate-first-batch.mjs") $batchValidator

# ------------------------------------------------------------------
# 7. Manual approval helper. It requires an explicit confirmation token.
# ------------------------------------------------------------------

$approveBatch = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

if (
  process.argv[2] !==
  "I_REVIEWED_THE_VISUALS"
) {
  console.error(
    "Approval blocked. After visually reviewing the first batch, run:"
  );

  console.error(
    "pnpm assets:first-batch:approve I_REVIEWED_THE_VISUALS"
  );

  process.exit(1);
}

const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow"
];

for (const id of ids) {
  const manifestPath =
    path.join(
      root,
      "assets",
      "manifests",
      `${id}.json`
    );

  const m =
    JSON.parse(
      fs.readFileSync(
        manifestPath,
        "utf8"
      )
    );

  m.commercialRightsConfirmed =
    true;

  m.originalityReviewed =
    true;

  m.childSafetyReviewed =
    true;

  if (
    m.culturalReviewRequired ===
    true
  ) {
    console.error(
      `${id}: cultural review is required; batch auto-approval cannot continue.`
    );

    process.exit(1);
  }

  m.status =
    "production";

  m.commercialReady =
    true;

  m.replacementRequiredForCommercialRelease =
    false;

  m.reviewedBy =
    "HIBEYA owner visual review";

  m.reviewedAt =
    new Date().toISOString();

  fs.writeFileSync(
    manifestPath,
    JSON.stringify(
      m,
      null,
      2
    ) + "\n",
    "utf8"
  );

  const briefPath =
    path.join(
      root,
      "assets",
      "briefs",
      `${id}.json`
    );

  if (fs.existsSync(briefPath)) {
    const b =
      JSON.parse(
        fs.readFileSync(
          briefPath,
          "utf8"
        )
      );

    b.status =
      "production";

    fs.writeFileSync(
      briefPath,
      JSON.stringify(
        b,
        null,
        2
      ) + "\n",
      "utf8"
    );
  }
}

console.log(
  "FIRST ORIGINAL ASSET BATCH: APPROVED FOR PRODUCTION"
);
'@
WriteText (Join-Path $tools "approve-first-batch.mjs") $approveBatch

# ------------------------------------------------------------------
# 8. Storybook gallery for human review.
# ------------------------------------------------------------------

$storybookPackage = Join-Path $root "apps\ui-storybook\package.json"
Backup $storybookPackage

$galleryEditor = Join-Path $env:TEMP "hibeya-phase007d-storybook.cjs"
WriteText $galleryEditor @'
const fs = require("fs");
const p = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(p, "utf8"));
pkg.dependencies ??= {};
pkg.dependencies["@akal-budi/assets"] = "workspace:*";
fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n","utf8");
'@
& node $galleryEditor $storybookPackage
if ($LASTEXITCODE -ne 0) { throw "Storybook package update failed." }
Remove-Item $galleryEditor -Force -ErrorAction SilentlyContinue

$gallery = @'
import {
  getAsset
} from "@akal-budi/assets";

const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow"
];

export default {
  title:
    "Assets/First Original Batch"
};

export function ReviewGallery() {
  return (
    <main
      style={{
        padding: "2rem",
        fontFamily: "system-ui, sans-serif"
      }}
    >
      <h1>
        HIBEYA First Original Asset Batch
      </h1>

      <p>
        Review silhouette clarity, child suitability,
        visual consistency and originality before approval.
      </p>

      <div
        style={{
          display: "grid",
          gridTemplateColumns:
            "repeat(auto-fit, minmax(180px, 1fr))",
          gap: "1.5rem",
          marginTop: "2rem"
        }}
      >
        {ids.map(
          id => {
            const asset =
              getAsset(
                id
              );

            return (
              <figure
                key={id}
                style={{
                  margin: 0,
                  padding: "1.5rem",
                  border: "1px solid #d7dee4",
                  borderRadius: "1rem",
                  background: "#fff"
                }}
              >
                <img
                  src={asset.value}
                  alt={asset.alt.en}
                  style={{
                    display: "block",
                    width: "160px",
                    height: "160px",
                    objectFit: "contain",
                    margin: "0 auto"
                  }}
                />

                <figcaption
                  style={{
                    marginTop: "1rem",
                    textAlign: "center",
                    fontWeight: 600
                  }}
                >
                  {asset.alt.ms}
                  <br />
                  <small>
                    {id}
                  </small>
                </figcaption>
              </figure>
            );
          }
        )}
      </div>
    </main>
  );
}
'@
WriteText (Join-Path $root "apps\ui-storybook\stories\CommercialAssets.stories.tsx") $gallery

# ------------------------------------------------------------------
# 9. Root scripts
# ------------------------------------------------------------------

$rootPackage = Join-Path $root "package.json"
Backup $rootPackage

$editor = Join-Path $env:TEMP "hibeya-phase007d-package.cjs"
WriteText $editor @'
const fs = require("fs");
const p = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(p,"utf8"));
pkg.scripts ??= {};
pkg.scripts["assets:first-batch:prepare"] =
  "node tools/assets/prepare-first-batch-review.mjs";
pkg.scripts["assets:first-batch:validate"] =
  "node tools/assets/validate-first-batch.mjs";
pkg.scripts["assets:first-batch:approve"] =
  "node tools/assets/approve-first-batch.mjs";
fs.writeFileSync(p,JSON.stringify(pkg,null,2)+"\n","utf8");
'@
& node $editor $rootPackage
if ($LASTEXITCODE -ne 0) { throw "Root package update failed." }
Remove-Item $editor -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------------
# 10. Prepare manifests and validate.
# ------------------------------------------------------------------

Run "Workspace install" "pnpm install"
Run "Prepare first asset batch review state" "pnpm assets:first-batch:prepare"
Run "First asset batch validation" "pnpm assets:first-batch:validate"
Run "Asset production pipeline validation" "pnpm assets:pipeline:validate"
Run "Illustration system validation" "pnpm illustration:validate"
Run "Asset provenance validation" "pnpm assets:validate"
Run "Storybook production build" "pnpm storybook:build"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression verification" "pnpm qa:visual"
Run "Content compiler check" "pnpm content:check"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Curriculum source validation" "pnpm curriculum:sources:validate"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run "Stage Phase 007D" "git add assets/masters assets/exports assets/manifests assets/briefs packages/assets apps/learner-web/src/features/play/ActivityPlayer.tsx apps/ui-storybook tools/assets package.json pnpm-lock.yaml"
  Run "Commit Phase 007D" 'git commit -m "feat: add first original Hibeya learner asset batch"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007D: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Review the assets visually with:" -ForegroundColor Cyan
Write-Host "  pnpm storybook" -ForegroundColor White
Write-Host ""
Write-Host "Open Storybook -> Assets -> First Original Batch -> Review Gallery" -ForegroundColor White
Write-Host ""
Write-Host "After visual review, approve with:" -ForegroundColor Cyan
Write-Host "  pnpm assets:first-batch:approve I_REVIEWED_THE_VISUALS" -ForegroundColor White
Write-Host ""
Write-Host "Then run:" -ForegroundColor Cyan
Write-Host "  pnpm assets:validate" -ForegroundColor White
