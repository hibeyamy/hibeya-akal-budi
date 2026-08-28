Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs "phase008r3a2-asset-foundation-$stamp"
$log = Join-Path $work "phase008r3a2.log"
$zip = Join-Path $logs "phase008r3a2-asset-foundation-$stamp.zip"
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
    $Text | Tee-Object -FilePath $log -Append
}

function Run([string]$Label, [string]$Command) {
    Log ""
    Log "==> $Label"
    Log $Command

    $output = & cmd.exe /d /s /c $Command 2>&1
    $code = $LASTEXITCODE
    $output | Tee-Object -FilePath $log -Append

    if ($code -ne 0) {
        throw "$Label failed with exit code $code."
    }

    Log "PASS: $Label"
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText(
        $Path,
        $Content,
        [Text.UTF8Encoding]::new($false)
    )
}

function Backup([string]$Relative) {
    $source = Join-Path $root $Relative
    if (Test-Path $source) {
        $target = Join-Path $work ("before_" + ($Relative -replace '[\\/:*?"<>|]', '_'))
        Copy-Item $source $target -Force
    }
}

trap {
    Log ""
    Log "PHASE 008R3A.2: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace

    if (Test-Path $zip) {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "PHASE 008R3A.2: FAILED" -ForegroundColor Red
    Write-Host "Diagnostic ZIP: $zip" -ForegroundColor Yellow
    exit 1
}

Set-Location $root

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.2" -ForegroundColor Cyan
Write-Host "Asset Architecture Foundation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "HIBEYA AKAL BUDI - PHASE 008R3A.2"
Log "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"

$assetIndex = Join-Path $root "packages\assets\src\index.ts"
$commercial = Join-Path $root "packages\assets\src\commercial.ts"
$baselineStory = Join-Path $root "apps\ui-storybook\stories\ProductionVisualBaseline.stories.tsx"
$hibiscusStory = Join-Path $root "apps\ui-storybook\stories\HibiscusAssets.stories.tsx"
$storybookPackage = Join-Path $root "apps\ui-storybook\package.json"

foreach ($required in @(
    $assetIndex,
    $commercial,
    $baselineStory,
    $hibiscusStory,
    $storybookPackage,
    (Join-Path $root "pnpm-lock.yaml")
)) {
    if (-not (Test-Path $required)) {
        throw "Required file missing: $required"
    }
}

$currentIndex = Get-Content $assetIndex -Raw
if ($currentIndex -notmatch 'commercialAssetOverrides' -or $currentIndex -notmatch 'export function getAsset') {
    throw "Current asset resolution boundary does not match the inspected preflight contract."
}

$currentCommercial = Get-Content $commercial -Raw
if ($currentCommercial -notmatch 'generatedCommercialAssetOverrides') {
    throw "Commercial override contract does not match the inspected preflight state."
}

Backup "packages\assets\src\index.ts"
Backup "apps\ui-storybook\stories\ProductionVisualBaseline.stories.tsx"
Backup "apps\ui-storybook\stories\HibiscusAssets.stories.tsx"
Backup "apps\ui-storybook\package.json"
Backup "pnpm-lock.yaml"

# ---------------------------------------------------------------------------
# Governance metadata. This deliberately describes lifecycle and format policy
# without claiming that the legacy fruit artwork has already been approved.
# ---------------------------------------------------------------------------

$metadataPath = Join-Path $root "packages\assets\src\metadata.ts"
$metadata = @'
export const assetStatuses = [
  "legacy",
  "draft",
  "review",
  "approved",
  "retired"
] as const;

export type AssetStatus =
  (typeof assetStatuses)[number];

export const assetVisualFamilies = [
  "legacy",
  "hibeya-learning-v1"
] as const;

export type AssetVisualFamily =
  (typeof assetVisualFamilies)[number];

export interface AssetGovernanceMetadata {
  id: string;
  category:
    | "fruit"
    | "flora"
    | "ui"
    | "other";
  status: AssetStatus;
  version: number;
  visualFamily: AssetVisualFamily;
  sourceFormat:
    | "emoji"
    | "svg"
    | "png"
    | "webp"
    | "other";
  deliveryFormat:
    | "emoji"
    | "svg"
    | "png"
    | "webp"
    | "other";
  richIllustration: boolean;
  notes?: string;
}

export const assetGovernanceMetadata:
  Readonly<Record<string, AssetGovernanceMetadata>> = {
    "apple-red": {
      id: "apple-red",
      category: "fruit",
      status: "legacy",
      version: 1,
      visualFamily: "legacy",
      sourceFormat: "svg",
      deliveryFormat: "emoji",
      richIllustration: true,
      notes:
        "Pending raster artwork migration. Semantic ID is stable."
    },
    "apple-green": {
      id: "apple-green",
      category: "fruit",
      status: "legacy",
      version: 1,
      visualFamily: "legacy",
      sourceFormat: "svg",
      deliveryFormat: "emoji",
      richIllustration: true,
      notes:
        "Pending raster artwork migration. Semantic ID is stable."
    },
    "banana-yellow": {
      id: "banana-yellow",
      category: "fruit",
      status: "legacy",
      version: 1,
      visualFamily: "legacy",
      sourceFormat: "svg",
      deliveryFormat: "emoji",
      richIllustration: true,
      notes:
        "Pending raster artwork migration. Semantic ID is stable."
    },
    "hibiscus-red": {
      id: "hibiscus-red",
      category: "flora",
      status: "review",
      version: 1,
      visualFamily: "hibeya-learning-v1",
      sourceFormat: "png",
      deliveryFormat: "webp",
      richIllustration: true
    },
    "hibiscus-yellow": {
      id: "hibiscus-yellow",
      category: "flora",
      status: "review",
      version: 1,
      visualFamily: "hibeya-learning-v1",
      sourceFormat: "png",
      deliveryFormat: "webp",
      richIllustration: true
    },
    "hibiscus-purple": {
      id: "hibiscus-purple",
      category: "flora",
      status: "review",
      version: 1,
      visualFamily: "hibeya-learning-v1",
      sourceFormat: "png",
      deliveryFormat: "webp",
      richIllustration: true
    }
  };

export function getAssetMetadata(
  assetId: string
): AssetGovernanceMetadata {
  const metadata =
    assetGovernanceMetadata[assetId];

  if (!metadata) {
    throw new Error(
      `Unknown asset metadata: ${assetId}`
    );
  }

  return metadata;
}
'@
Write-Utf8NoBom $metadataPath $metadata

if ($currentIndex -notmatch 'from "./metadata"') {
    $newIndex = @'
export {
  assetGovernanceMetadata,
  assetStatuses,
  assetVisualFamilies,
  getAssetMetadata,
  type AssetGovernanceMetadata,
  type AssetStatus,
  type AssetVisualFamily
} from "./metadata";

'@ + $currentIndex
    Write-Utf8NoBom $assetIndex $newIndex
}

# ---------------------------------------------------------------------------
# Document the intended boundary without moving legacy files in this phase.
# ---------------------------------------------------------------------------

$sourceDir = Join-Path $root "packages\assets\source"
New-Item -ItemType Directory -Force -Path $sourceDir | Out-Null
$sourceReadme = @'
# Authoritative artwork sources

This directory is the future source-of-truth boundary for approved HIBEYA
learning artwork.

Policy:

- Rich learning illustrations use lossless PNG masters when appropriate.
- Runtime delivery should normally use optimised WebP derivatives.
- SVG remains suitable for simple UI/iconography, not as the default rich
  illustration format.
- Activities never reference physical filenames or formats. They reference
  stable semantic asset IDs resolved through `getAsset()`.
- Files are migrated here only through a governed migration phase. Existing
  generated assets are intentionally not moved by Phase 008R3A.2.
'@
Write-Utf8NoBom (Join-Path $sourceDir "README.md") $sourceReadme

# ---------------------------------------------------------------------------
# Storybook must consume the same public resolution boundary as learner-web.
# It must not know physical generated paths or extensions.
# ---------------------------------------------------------------------------

$baseline = @'
import {
  getAsset,
  getAssetMetadata,
  type AssetDefinition
} from "@akal-budi/assets";

const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow",
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
] as const;

function AssetVisual({
  asset
}: {
  asset: AssetDefinition;
}) {
  if (asset.type === "image") {
    return (
      <img
        src={asset.value}
        alt={asset.alt.en}
        style={{
          display: "block",
          width: "180px",
          height: "180px",
          objectFit: "contain",
          margin: "0 auto"
        }}
      />
    );
  }

  return (
    <div
      role="img"
      aria-label={asset.alt.en}
      style={{
        width: "180px",
        height: "180px",
        display: "grid",
        placeItems: "center",
        margin: "0 auto",
        fontSize: "7rem",
        lineHeight: 1
      }}
    >
      {asset.value}
    </div>
  );
}

export default {
  title: "Assets/Production Visual Baseline"
};

export function SixAssetAudit() {
  const assets = ids.map(id => ({
    asset: getAsset(id),
    metadata: getAssetMetadata(id)
  }));

  return (
    <main
      style={{
        padding: "2rem",
        fontFamily: "system-ui, sans-serif",
        background: "#faf8f2",
        minHeight: "100vh"
      }}
    >
      <h1>
        HIBEYA Akal Budi — Production Visual Baseline
      </h1>

      <p>
        All visuals on this page resolve through the same semantic
        getAsset() boundary used by the learner application.
      </p>

      <div
        style={{
          display: "grid",
          gridTemplateColumns:
            "repeat(auto-fit,minmax(220px,1fr))",
          gap: "1.25rem",
          marginTop: "2rem"
        }}
      >
        {assets.map(({ asset, metadata }) => (
          <figure
            key={asset.id}
            style={{
              margin: 0,
              padding: "1.5rem",
              border: "1px solid #e5dfd2",
              borderRadius: "20px",
              background: "#fff",
              boxShadow:
                "0 8px 24px rgba(35,51,63,.08)"
            }}
          >
            <AssetVisual asset={asset} />
            <figcaption
              style={{
                textAlign: "center",
                marginTop: "1rem",
                fontWeight: 700
              }}
            >
              {asset.alt.ms}
              <br />
              <small style={{ fontWeight: 500 }}>
                {asset.id}
                {" · "}
                {metadata.status}
                {" · "}
                {metadata.deliveryFormat}
              </small>
            </figcaption>
          </figure>
        ))}
      </div>
    </main>
  );
}
'@
Write-Utf8NoBom $baselineStory $baseline

$hibiscus = @'
import {
  getAsset,
  getAssetMetadata
} from "@akal-budi/assets";

const ids = [
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
] as const;

export default {
  title: "Assets/Malaysian Garden Hibiscus"
};

export function ReviewGallery() {
  const assets = ids.map(id => ({
    asset: getAsset(id),
    metadata: getAssetMetadata(id)
  }));

  return (
    <main
      style={{
        padding: "2rem",
        fontFamily: "system-ui, sans-serif"
      }}
    >
      <h1>
        HIBEYA Malaysian Garden — Hibiscus Review
      </h1>

      <p>
        These review visuals resolve through getAsset(); Storybook
        does not reference generated SVG, PNG or WebP files directly.
      </p>

      <div
        style={{
          display: "grid",
          gridTemplateColumns:
            "repeat(auto-fit, minmax(200px, 1fr))",
          gap: "1.5rem",
          marginTop: "2rem"
        }}
      >
        {assets.map(({ asset, metadata }) => (
          <figure
            key={asset.id}
            style={{
              margin: 0,
              padding: "1.5rem",
              border: "1px solid #d7dee4",
              borderRadius: "1rem",
              background: "#fff"
            }}
          >
            {asset.type === "image" ? (
              <img
                src={asset.value}
                alt={asset.alt.en}
                style={{
                  display: "block",
                  width: "180px",
                  height: "180px",
                  objectFit: "contain",
                  margin: "0 auto"
                }}
              />
            ) : (
              <div
                role="img"
                aria-label={asset.alt.en}
                style={{
                  width: "180px",
                  height: "180px",
                  display: "grid",
                  placeItems: "center",
                  margin: "0 auto",
                  fontSize: "7rem"
                }}
              >
                {asset.value}
              </div>
            )}

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
                {asset.id}
                {" · "}
                {metadata.deliveryFormat}
              </small>
            </figcaption>
          </figure>
        ))}
      </div>
    </main>
  );
}
'@
Write-Utf8NoBom $hibiscusStory $hibiscus

# Ensure Storybook has an explicit workspace dependency rather than relying
# on transitive/hoisted resolution.
$pkg = Get-Content $storybookPackage -Raw | ConvertFrom-Json
if ($null -eq $pkg.dependencies) {
    $pkg | Add-Member -NotePropertyName dependencies -NotePropertyValue ([PSCustomObject]@{})
}

$hasAssetDependency =
    $null -ne $pkg.dependencies.PSObject.Properties["@akal-budi/assets"]

if (-not $hasAssetDependency) {
    $pkg.dependencies |
        Add-Member -NotePropertyName "@akal-budi/assets" -NotePropertyValue "workspace:*"

    $json = $pkg | ConvertTo-Json -Depth 20
    Write-Utf8NoBom $storybookPackage ($json + [Environment]::NewLine)

    Run "Reconcile workspace lockfile" "pnpm install --no-frozen-lockfile"
}

Run "Verify frozen lockfile" "pnpm install --frozen-lockfile"

# Contract assertions before expensive validation.
$baselineNow = Get-Content $baselineStory -Raw
$hibiscusNow = Get-Content $hibiscusStory -Raw

foreach ($storyText in @($baselineNow, $hibiscusNow)) {
    if ($storyText -match 'src/generated' -or
        $storyText -match '\.svg' -or
        $storyText -match '\.webp' -or
        $storyText -match '\.png') {
        throw "Storybook still contains physical asset-format/path knowledge."
    }

    if ($storyText -notmatch 'getAsset') {
        throw "Storybook does not consume the semantic asset resolver."
    }
}

$indexNow = Get-Content $assetIndex -Raw
if ($indexNow -notmatch 'getAssetMetadata') {
    throw "Asset governance metadata is not exported from the package boundary."
}

Log "PASS: semantic resolver is the Storybook asset boundary"
Log "PASS: governance metadata contract installed"
Log "PASS: legacy artwork files were not moved or deleted"

Run "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run "Learner web tests" "pnpm --filter learner-web test"
Run "Storybook production build" "pnpm --filter ui-storybook build-storybook"

$compiler = Join-Path $root "tools\content-compiler\compile.mjs"
if (Test-Path $compiler) {
    Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
}

Log ""
Log "PASS: Phase 008R3A.2 Asset Architecture Foundation"
Log "Next: Phase 008R3A.3 Legacy Asset Migration"
Log "No activity manifest, approval state, learner progression rule, or curriculum ordering rule was changed."

if (Test-Path $zip) {
    Remove-Item $zip -Force
}
Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force

Write-Host ""
Write-Host "PHASE 008R3A.2: PASS" -ForegroundColor Green
Write-Host "Log ZIP: $zip" -ForegroundColor Cyan
exit 0
