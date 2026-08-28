param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$masters = Join-Path $root "assets\masters"
$exports = Join-Path $root "assets\exports"
$runtime = Join-Path $root "packages\assets\src\generated"
$tools = Join-Path $root "tools\assets"
$families = Join-Path $root "assets\families"

New-Item -ItemType Directory -Force -Path $logs,$backups,$masters,$exports,$runtime,$tools,$families | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007g-$runId.log"

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

  $relative =
    $Path.Substring(
      $root.Length
    ).TrimStart("\")

  $safe =
    $relative.Replace(
      "\",
      "__"
    )

  Copy-Item `
    $Path `
    (Join-Path $backups "$runId-$safe") `
    -Force
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`n$Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase007g-$stamp-out.log"
  $err = Join-Path $logs "phase007g-$stamp-err.log"

  $p = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err `
    -NoNewWindow `
    -Wait `
    -PassThru

  $o = if (Test-Path $out) { Get-Content $out -Raw } else { "" }
  $e = if (Test-Path $err) { Get-Content $err -Raw } else { "" }

  if ($o) {
    Write-Host $o
    Add-Content $log $o -Encoding UTF8
  }

  if ($e) {
    Write-Host $e
    Add-Content $log $e -Encoding UTF8
  }

  if ($p.ExitCode -ne 0) {
    $diag =
      Join-Path `
        $logs `
        "FAILED-phase007g-$stamp-$($Name.Replace(' ','-')).log"

    WriteText `
      $diag `
      "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$o`n`nSTDERR:`n$e"

    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue

  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 007G: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007G" -ForegroundColor Cyan
Write-Host "Original Malaysian Garden Hibiscus Batch" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ============================================================
# 1. Deterministic original hibiscus SVG review candidates
# ============================================================

$hibiscusRed = @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 320" role="img" aria-labelledby="title desc">
  <title id="title">Red hibiscus</title>
  <desc id="desc">Original HIBEYA illustration of a simple red bunga raya flower.</desc>
  <g stroke="#23333F" stroke-width="8" stroke-linecap="round" stroke-linejoin="round">
    <path d="M160 157 C115 91 63 93 54 132 C46 166 76 188 116 178 C79 204 82 246 117 257 C151 268 171 235 163 198 C178 235 216 250 240 222 C263 195 242 166 207 158 C246 150 263 115 239 91 C214 66 177 86 160 124 C143 86 106 66 81 91 C57 115 74 150 113 158 Z"
      fill="#E65355"/>
    <circle cx="160" cy="160" r="30" fill="#F6B4A8"/>
    <path d="M160 158 C184 152 209 139 232 118" fill="none"/>
    <path d="M232 118 C247 106 257 92 263 78" fill="none"/>
    <circle cx="264" cy="76" r="8" fill="#F4C84A"/>
    <circle cx="250" cy="91" r="5" fill="#F4C84A"/>
    <circle cx="239" cy="104" r="5" fill="#F4C84A"/>
  </g>
</svg>
'@

$hibiscusYellow = @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 320" role="img" aria-labelledby="title desc">
  <title id="title">Yellow hibiscus</title>
  <desc id="desc">Original HIBEYA illustration of a simple yellow hibiscus flower.</desc>
  <g stroke="#23333F" stroke-width="8" stroke-linecap="round" stroke-linejoin="round">
    <path d="M160 157 C115 91 63 93 54 132 C46 166 76 188 116 178 C79 204 82 246 117 257 C151 268 171 235 163 198 C178 235 216 250 240 222 C263 195 242 166 207 158 C246 150 263 115 239 91 C214 66 177 86 160 124 C143 86 106 66 81 91 C57 115 74 150 113 158 Z"
      fill="#F4C84A"/>
    <circle cx="160" cy="160" r="30" fill="#D66B52"/>
    <path d="M160 158 C184 152 209 139 232 118" fill="none"/>
    <path d="M232 118 C247 106 257 92 263 78" fill="none"/>
    <circle cx="264" cy="76" r="8" fill="#E65355"/>
    <circle cx="250" cy="91" r="5" fill="#E65355"/>
    <circle cx="239" cy="104" r="5" fill="#E65355"/>
  </g>
</svg>
'@

$hibiscusPurple = @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 320" role="img" aria-labelledby="title desc">
  <title id="title">Purple hibiscus</title>
  <desc id="desc">Original HIBEYA illustration of a simple purple hibiscus flower.</desc>
  <g stroke="#23333F" stroke-width="8" stroke-linecap="round" stroke-linejoin="round">
    <path d="M160 157 C115 91 63 93 54 132 C46 166 76 188 116 178 C79 204 82 246 117 257 C151 268 171 235 163 198 C178 235 216 250 240 222 C263 195 242 166 207 158 C246 150 263 115 239 91 C214 66 177 86 160 124 C143 86 106 66 81 91 C57 115 74 150 113 158 Z"
      fill="#9A6CC1"/>
    <circle cx="160" cy="160" r="30" fill="#F2B7D0"/>
    <path d="M160 158 C184 152 209 139 232 118" fill="none"/>
    <path d="M232 118 C247 106 257 92 263 78" fill="none"/>
    <circle cx="264" cy="76" r="8" fill="#F4C84A"/>
    <circle cx="250" cy="91" r="5" fill="#F4C84A"/>
    <circle cx="239" cy="104" r="5" fill="#F4C84A"/>
  </g>
</svg>
'@

$batch = @{
  "hibiscus-red" = $hibiscusRed
  "hibiscus-yellow" = $hibiscusYellow
  "hibiscus-purple" = $hibiscusPurple
}

foreach ($id in $batch.Keys) {
  $master = Join-Path $masters "$id.svg"
  $export = Join-Path $exports "$id.svg"
  $runtimeFile = Join-Path $runtime "$id.svg"

  Backup $master
  Backup $export
  Backup $runtimeFile

  WriteText $master $batch[$id]
  WriteText $export $batch[$id]
  WriteText $runtimeFile $batch[$id]
}

Write-Host "PASS: 3 original hibiscus SVG review candidates created" -ForegroundColor Green

# ============================================================
# 2. Prepare review state without self-approval
# ============================================================

$prepare = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const metadata = {
  "hibiscus-red": {
    alt: {
      ms: "Bunga raya merah",
      en: "Red hibiscus"
    }
  },
  "hibiscus-yellow": {
    alt: {
      ms: "Bunga raya kuning",
      en: "Yellow hibiscus"
    }
  },
  "hibiscus-purple": {
    alt: {
      ms: "Bunga raya ungu",
      en: "Purple hibiscus"
    }
  }
};

for (const [id, data] of Object.entries(metadata)) {
  const manifestPath =
    path.join(
      root,
      "assets",
      "manifests",
      `${id}.json`
    );

  if (!fs.existsSync(manifestPath)) {
    console.error(`Missing provenance manifest: ${id}`);
    process.exit(1);
  }

  const manifest =
    JSON.parse(
      fs.readFileSync(
        manifestPath,
        "utf8"
      )
    );

  manifest.status =
    "review";

  manifest.currentRepresentation =
    "svg";

  manifest.sourceType =
    "original-internal";

  manifest.creator =
    "HIBEYA deterministic vector production";

  manifest.sourceFile =
    `assets/masters/${id}.svg`;

  manifest.sourceValue =
    null;

  manifest.commercialRightsConfirmed =
    false;

  manifest.originalityReviewed =
    false;

  manifest.childSafetyReviewed =
    false;

  manifest.culturalReviewRequired =
    true;

  manifest.culturalReviewed =
    false;

  manifest.commercialReady =
    false;

  manifest.replacementRequiredForCommercialRelease =
    true;

  manifest.runtime = {
    alt:
      data.alt,

    file:
      `packages/assets/src/generated/${id}.svg`
  };

  manifest.notes =
    "Original HIBEYA hibiscus SVG candidate created in Phase 007G. Human visual, originality, child-safety, commercial-rights and Malaysian cultural-context review are required before approval.";

  fs.writeFileSync(
    manifestPath,
    JSON.stringify(
      manifest,
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
    const brief =
      JSON.parse(
        fs.readFileSync(
          briefPath,
          "utf8"
        )
      );

    brief.productionMethod =
      "original-internal";

    brief.status =
      "review";

    brief.malaysianContext =
      [
        "bunga raya",
        "Malaysian national flower context"
      ];

    brief.culturalReviewRequired =
      true;

    fs.writeFileSync(
      briefPath,
      JSON.stringify(
        brief,
        null,
        2
      ) + "\n",
      "utf8"
    );
  }
}

console.log(
  "HIBISCUS BATCH: review state prepared"
);
'@

WriteText `
  (Join-Path $tools "prepare-hibiscus-batch-review.mjs") `
  $prepare

# ============================================================
# 3. Candidate validator
# ============================================================

$validator = @'
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const ids = [
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
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
    path.join(root,"assets","masters",`${id}.svg`);

  const exported =
    path.join(root,"assets","exports",`${id}.svg`);

  const runtime =
    path.join(root,"packages","assets","src","generated",`${id}.svg`);

  const manifestPath =
    path.join(root,"assets","manifests",`${id}.json`);

  for (const file of [master,exported,runtime,manifestPath]) {
    if (!fs.existsSync(file)) {
      failures.push(`${id}: missing ${path.relative(root,file)}`);
    }
  }

  if (
    fs.existsSync(master) &&
    fs.existsSync(exported) &&
    fs.existsSync(runtime)
  ) {
    if (
      new Set(
        [
          hash(master),
          hash(exported),
          hash(runtime)
        ]
      ).size !==
      1
    ) {
      failures.push(
        `${id}: master/export/runtime hashes differ`
      );
    }

    const svg =
      fs.readFileSync(
        master,
        "utf8"
      );

    if (
      /<script\b/i.test(svg) ||
      /\bon[a-z]+\s*=/i.test(svg) ||
      /<foreignObject\b/i.test(svg)
    ) {
      failures.push(
        `${id}: unsafe SVG content`
      );
    }
  }

  if (fs.existsSync(manifestPath)) {
    const manifest =
      JSON.parse(
        fs.readFileSync(
          manifestPath,
          "utf8"
        )
      );

    if (manifest.status !== "review")
      failures.push(`${id}: expected review status`);

    if (manifest.commercialReady !== false)
      failures.push(`${id}: candidate must not self-approve`);

    if (manifest.culturalReviewRequired !== true)
      failures.push(`${id}: cultural review must be required`);

    if (manifest.culturalReviewed !== false)
      failures.push(`${id}: cultural review must remain pending before manual approval`);
  }
}

if (failures.length) {
  for (const failure of failures) {
    console.error(`HIBISCUS BATCH ERROR: ${failure}`);
  }

  process.exit(1);
}

console.log(
  "HIBISCUS BATCH VALIDATION: PASS (3 review candidates)"
);
'@

WriteText `
  (Join-Path $tools "validate-hibiscus-batch.mjs") `
  $validator

# ============================================================
# 4. Explicit human approval + family creation
# ============================================================

$approve = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

if (
  process.argv[2] !==
  "I_REVIEWED_VISUALS_AND_CULTURE"
) {
  console.error(
    "Approval blocked."
  );

  console.error(
    "After reviewing visual quality AND Malaysian cultural context, run:"
  );

  console.error(
    "pnpm assets:hibiscus-batch:approve I_REVIEWED_VISUALS_AND_CULTURE"
  );

  process.exit(1);
}

const ids = [
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

for (const id of ids) {
  const manifestPath =
    path.join(
      root,
      "assets",
      "manifests",
      `${id}.json`
    );

  const manifest =
    JSON.parse(
      fs.readFileSync(
        manifestPath,
        "utf8"
      )
    );

  manifest.commercialRightsConfirmed =
    true;

  manifest.originalityReviewed =
    true;

  manifest.childSafetyReviewed =
    true;

  manifest.culturalReviewed =
    true;

  manifest.status =
    "production";

  manifest.commercialReady =
    true;

  manifest.replacementRequiredForCommercialRelease =
    false;

  manifest.reviewedBy =
    "HIBEYA owner visual and cultural review";

  manifest.reviewedAt =
    new Date().toISOString();

  fs.writeFileSync(
    manifestPath,
    JSON.stringify(
      manifest,
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
    const brief =
      JSON.parse(
        fs.readFileSync(
          briefPath,
          "utf8"
        )
      );

    brief.status =
      "production";

    fs.writeFileSync(
      briefPath,
      JSON.stringify(
        brief,
        null,
        2
      ) + "\n",
      "utf8"
    );
  }
}

const family = {
  schemaVersion:
    1,

  id:
    "malaysian-garden-hibiscus",

  version:
    "1.0.0",

  title:
    "Malaysian Garden Hibiscus",

  purpose:
    "Commercial HIBEYA hibiscus assets for Malaysian-context learner activities.",

  commercialReleaseRequiresHumanApproval:
    true,

  members:
    ids.map(
      id => ({
        id,
        master:
          `assets/masters/${id}.svg`,
        export:
          `assets/exports/${id}.svg`,
        runtime:
          `packages/assets/src/generated/${id}.svg`
      })
    )
};

fs.writeFileSync(
  path.join(
    root,
    "assets",
    "families",
    "malaysian-garden-hibiscus.json"
  ),
  JSON.stringify(
    family,
    null,
    2
  ) + "\n",
  "utf8"
);

console.log(
  "HIBISCUS BATCH: APPROVED FOR PRODUCTION"
);
'@

WriteText `
  (Join-Path $tools "approve-hibiscus-batch.mjs") `
  $approve

# ============================================================
# 5. Storybook review gallery uses candidate SVGs directly
# ============================================================

$gallery = @'
const assets = [
  {
    id:
      "hibiscus-red",

    ms:
      "Bunga raya merah",

    en:
      "Red hibiscus",

    src:
      new URL(
        "../../../packages/assets/src/generated/hibiscus-red.svg",
        import.meta.url
      ).href
  },
  {
    id:
      "hibiscus-yellow",

    ms:
      "Bunga raya kuning",

    en:
      "Yellow hibiscus",

    src:
      new URL(
        "../../../packages/assets/src/generated/hibiscus-yellow.svg",
        import.meta.url
      ).href
  },
  {
    id:
      "hibiscus-purple",

    ms:
      "Bunga raya ungu",

    en:
      "Purple hibiscus",

    src:
      new URL(
        "../../../packages/assets/src/generated/hibiscus-purple.svg",
        import.meta.url
      ).href
  }
];

export default {
  title:
    "Assets/Malaysian Garden Hibiscus"
};

export function ReviewGallery() {
  return (
    <main
      style={{
        padding:
          "2rem",

        fontFamily:
          "system-ui, sans-serif"
      }}
    >
      <h1>
        HIBEYA Malaysian Garden — Hibiscus Review
      </h1>

      <p>
        Review recognisability, petal/stamen clarity,
        child suitability, consistency, originality
        and appropriate Malaysian bunga raya context.
      </p>

      <div
        style={{
          display:
            "grid",

          gridTemplateColumns:
            "repeat(auto-fit, minmax(200px, 1fr))",

          gap:
            "1.5rem",

          marginTop:
            "2rem"
        }}
      >
        {assets.map(
          asset => (
            <figure
              key={asset.id}
              style={{
                margin:
                  0,

                padding:
                  "1.5rem",

                border:
                  "1px solid #d7dee4",

                borderRadius:
                  "1rem",

                background:
                  "#fff"
              }}
            >
              <img
                src={asset.src}
                alt={asset.en}
                style={{
                  display:
                    "block",

                  width:
                    "180px",

                  height:
                    "180px",

                  objectFit:
                    "contain",

                  margin:
                    "0 auto"
                }}
              />

              <figcaption
                style={{
                  marginTop:
                    "1rem",

                  textAlign:
                    "center",

                  fontWeight:
                    600
                }}
              >
                {asset.ms}
                <br />
                <small>
                  {asset.id}
                </small>
              </figcaption>
            </figure>
          )
        )}
      </div>
    </main>
  );
}
'@

WriteText `
  (Join-Path $root "apps\ui-storybook\stories\HibiscusAssets.stories.tsx") `
  $gallery

# ============================================================
# 6. Root scripts
# ============================================================

$packagePath =
  Join-Path `
    $root `
    "package.json"

Backup $packagePath

$temp =
  Join-Path `
    $env:TEMP `
    "hibeya-phase007g-package.cjs"

WriteText $temp @'
const fs = require("fs");

const p =
  process.argv[2];

const pkg =
  JSON.parse(
    fs.readFileSync(
      p,
      "utf8"
    )
  );

pkg.scripts ??= {};

pkg.scripts["assets:hibiscus-batch:prepare"] =
  "node tools/assets/prepare-hibiscus-batch-review.mjs";

pkg.scripts["assets:hibiscus-batch:validate"] =
  "node tools/assets/validate-hibiscus-batch.mjs";

pkg.scripts["assets:hibiscus-batch:approve"] =
  "node tools/assets/approve-hibiscus-batch.mjs";

pkg.scripts["assets:hibiscus-batch:finalise"] =
  "pnpm assets:hibiscus-batch:approve I_REVIEWED_VISUALS_AND_CULTURE && pnpm assets:families:validate && pnpm assets:families:compile && pnpm assets:families:check && pnpm assets:runtime:compile && pnpm assets:runtime:check && pnpm assets:runtime:validate && pnpm assets:commercial:validate";

fs.writeFileSync(
  p,
  JSON.stringify(
    pkg,
    null,
    2
  ) + "\n",
  "utf8"
);
'@

& node `
  $temp `
  $packagePath

if (
  $LASTEXITCODE -ne 0
) {
  throw "package.json update failed"
}

Remove-Item `
  $temp `
  -Force `
  -ErrorAction SilentlyContinue

# ============================================================
# 7. Review-candidate QA
# ============================================================

Run `
  "Prepare hibiscus review state" `
  "pnpm assets:hibiscus-batch:prepare"

Run `
  "Hibiscus candidate validation" `
  "pnpm assets:hibiscus-batch:validate"

Run `
  "Asset provenance validation" `
  "pnpm assets:validate"

Run `
  "Asset production pipeline validation" `
  "pnpm assets:pipeline:validate"

Run `
  "Illustration system validation" `
  "pnpm illustration:validate"

Run `
  "Storybook production build" `
  "pnpm storybook:build"

Run `
  "Asset package typecheck" `
  "pnpm --filter @akal-budi/assets typecheck"

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
  "Visual regression verification" `
  "pnpm qa:visual"

Run `
  "Content compiler check" `
  "pnpm content:check"

Run `
  "Curriculum validation" `
  "pnpm curriculum:validate"

Run `
  "Curriculum source validation" `
  "pnpm curriculum:sources:validate"

Run `
  "Git whitespace check" `
  "git diff --check"

if ($Commit) {
  Run `
    "Stage Phase 007G" `
    "git add assets/masters assets/exports assets/manifests assets/briefs packages/assets/src/generated apps/ui-storybook/stories/HibiscusAssets.stories.tsx tools/assets package.json"

  Run `
    "Commit Phase 007G" `
    'git commit -m "feat: add original Malaysian garden hibiscus review batch"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007G: PASS - REVIEW CANDIDATES READY" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "MANUAL REVIEW IS REQUIRED BEFORE COMMERCIAL FINALISATION." -ForegroundColor Yellow
Write-Host ""
Write-Host "Run:" -ForegroundColor Cyan
Write-Host "  pnpm storybook" -ForegroundColor White
Write-Host ""
Write-Host "Open:" -ForegroundColor Cyan
Write-Host "  Assets -> Malaysian Garden Hibiscus -> Review Gallery" -ForegroundColor White
Write-Host ""
Write-Host "If visual quality and Malaysian cultural context are approved, run:" -ForegroundColor Cyan
Write-Host "  pnpm assets:hibiscus-batch:finalise" -ForegroundColor White
Write-Host ""
Write-Host "That finalisation will automatically rebuild family and commercial runtime registries" -ForegroundColor Cyan
Write-Host "and require the global commercial asset gate to PASS." -ForegroundColor Cyan
