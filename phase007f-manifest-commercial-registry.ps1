param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$tools = Join-Path $root "tools\assets"
$generated = Join-Path $root "packages\assets\src\generated"

New-Item -ItemType Directory -Force -Path $logs,$backups,$tools,$generated | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007f-$runId.log"

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
  $out = Join-Path $logs "phase007f-$stamp-out.log"
  $err = Join-Path $logs "phase007f-$stamp-err.log"

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
        "FAILED-phase007f-$stamp-$($Name.Replace(' ','-')).log"

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
  Write-Host "PHASE 007F: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007F" -ForegroundColor Cyan
Write-Host "Manifest-Driven Commercial Runtime Registry" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ============================================================
# 1. Migrate runtime metadata into approved manifests.
#    Preserve every existing approval/provenance field.
# ============================================================

$migrator = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const metadata = {
  "apple-red": {
    alt: {
      ms: "Epal merah",
      en: "Red apple"
    }
  },
  "apple-green": {
    alt: {
      ms: "Epal hijau",
      en: "Green apple"
    }
  },
  "banana-yellow": {
    alt: {
      ms: "Pisang kuning",
      en: "Yellow banana"
    }
  }
};

for (const [id, runtime] of Object.entries(metadata)) {
  const file =
    path.join(
      root,
      "assets",
      "manifests",
      `${id}.json`
    );

  if (!fs.existsSync(file)) {
    console.error(`Missing approved manifest: ${id}`);
    process.exit(1);
  }

  const manifest =
    JSON.parse(
      fs.readFileSync(
        file,
        "utf8"
      )
    );

  if (manifest.commercialReady !== true) {
    console.error(
      `${id}: expected commercialReady=true before registry migration`
    );

    process.exit(1);
  }

  manifest.runtime = {
    ...(manifest.runtime ?? {}),
    alt: runtime.alt,
    file: `packages/assets/src/generated/${id}.svg`
  };

  fs.writeFileSync(
    file,
    JSON.stringify(
      manifest,
      null,
      2
    ) + "\n",
    "utf8"
  );
}

console.log(
  "COMMERCIAL RUNTIME METADATA: migrated 3 approved assets"
);
'@

WriteText `
  (Join-Path $tools "migrate-runtime-metadata.mjs") `
  $migrator

# ============================================================
# 2. Manifest-driven compiler.
# ============================================================

$compiler = @'
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

const output =
  path.join(
    root,
    "packages",
    "assets",
    "src",
    "generated",
    "commercialRegistry.generated.ts"
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
    )
    .sort();

const approved = [];

for (const file of files) {
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
    manifest.commercialReady !==
    true
  ) {
    continue;
  }

  const id =
    manifest.id;

  if (
    !manifest.runtime?.file ||
    !manifest.runtime?.alt?.ms ||
    !manifest.runtime?.alt?.en
  ) {
    console.error(
      `${id}: commercial asset is missing runtime metadata`
    );

    process.exit(1);
  }

  const expectedRuntime =
    `packages/assets/src/generated/${id}.svg`;

  if (
    manifest.runtime.file !==
    expectedRuntime
  ) {
    console.error(
      `${id}: runtime file must be ${expectedRuntime}`
    );

    process.exit(1);
  }

  if (
    !fs.existsSync(
      path.join(
        root,
        manifest.runtime.file
      )
    )
  ) {
    console.error(
      `${id}: runtime asset file does not exist`
    );

    process.exit(1);
  }

  approved.push({
    id,
    alt:
      manifest.runtime.alt
  });
}

const lines = [];

lines.push(
  "// GENERATED FILE. DO NOT EDIT."
);

lines.push(
  "// Source: assets/manifests/*.json where commercialReady=true"
);

lines.push("");

lines.push(
  "export const generatedCommercialAssetOverrides = {"
);

for (const asset of approved) {
  lines.push(
    `  ${JSON.stringify(asset.id)}: {`
  );

  lines.push(
    `    id: ${JSON.stringify(asset.id)},`
  );

  lines.push(
    '    type: "image" as const,'
  );

  lines.push(
    "    value: new URL("
  );

  lines.push(
    `      ${JSON.stringify(`./${asset.id}.svg`)},`
  );

  lines.push(
    "      import.meta.url"
  );

  lines.push(
    "    ).href,"
  );

  lines.push(
    "    alt: {"
  );

  lines.push(
    `      ms: ${JSON.stringify(asset.alt.ms)},`
  );

  lines.push(
    `      en: ${JSON.stringify(asset.alt.en)}`
  );

  lines.push(
    "    }"
  );

  lines.push(
    "  },"
  );
}

lines.push(
  "} as const;"
);

lines.push("");

lines.push(
  "export type GeneratedCommercialAssetId ="
);

lines.push(
  "  keyof typeof generatedCommercialAssetOverrides;"
);

lines.push("");

const body =
  lines.join(
    "\n"
  ) +
  "\n";

const check =
  process.argv.includes(
    "--check"
  );

if (check) {
  if (
    !fs.existsSync(
      output
    ) ||
    fs.readFileSync(
      output,
      "utf8"
    ) !==
      body
  ) {
    console.error(
      "COMMERCIAL REGISTRY CHECK: generated output is out of date"
    );

    process.exit(1);
  }

  console.log(
    `COMMERCIAL REGISTRY CHECK: PASS (${approved.length} approved assets)`
  );

  process.exit(0);
}

fs.mkdirSync(
  path.dirname(
    output
  ),
  {
    recursive:
      true
  }
);

fs.writeFileSync(
  output,
  body,
  "utf8"
);

console.log(
  `COMMERCIAL REGISTRY: ${approved.length} approved assets compiled`
);
'@

WriteText `
  (Join-Path $tools "compile-commercial-registry.mjs") `
  $compiler

# ============================================================
# 3. Replace handwritten commercial.ts with thin typed bridge.
# ============================================================

$commercialPath =
  Join-Path `
    $root `
    "packages\assets\src\commercial.ts"

Backup $commercialPath

$commercialBridge = @'
import {
  generatedCommercialAssetOverrides
} from "./generated/commercialRegistry.generated";

export interface CommercialAssetOverride {
  id: string;

  type:
    "image";

  value:
    string;

  alt: {
    ms:
      string;

    en:
      string;
  };
}

export const commercialAssetOverrides:
  Record<
    string,
    CommercialAssetOverride
  > =
    generatedCommercialAssetOverrides;
'@

WriteText `
  $commercialPath `
  $commercialBridge

# ============================================================
# 4. Compiler integrity validator.
# ============================================================

$validator = @'
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

const generatedPath =
  path.join(
    root,
    "packages",
    "assets",
    "src",
    "generated",
    "commercialRegistry.generated.ts"
  );

const approved = [];

for (
  const file
  of fs.readdirSync(
    manifestRoot
  )
    .filter(
      file =>
        file.endsWith(
          ".json"
        )
    )
    .sort()
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
    manifest.commercialReady ===
    true
  ) {
    approved.push(
      manifest.id
    );
  }
}

if (
  !fs.existsSync(
    generatedPath
  )
) {
  console.error(
    "COMMERCIAL REGISTRY VALIDATION: generated registry missing"
  );

  process.exit(1);
}

const generated =
  fs.readFileSync(
    generatedPath,
    "utf8"
  );

for (
  const id
  of approved
) {
  if (
    !generated.includes(
      JSON.stringify(
        id
      )
    )
  ) {
    console.error(
      `COMMERCIAL REGISTRY VALIDATION: approved asset missing from runtime registry: ${id}`
    );

    process.exit(1);
  }
}

const declaredIds =
  [
    ...generated.matchAll(
      /^\s*"([^"]+)": \{$/gm
    )
  ]
    .map(
      match =>
        match[1]
    );

const unexpected =
  declaredIds.filter(
    id =>
      !approved.includes(
        id
      )
  );

if (
  unexpected.length >
  0
) {
  console.error(
    `COMMERCIAL REGISTRY VALIDATION: unapproved assets leaked into runtime registry: ${unexpected.join(", ")}`
  );

  process.exit(1);
}

console.log(
  `COMMERCIAL REGISTRY VALIDATION: PASS (${approved.length} approved assets)`
);
'@

WriteText `
  (Join-Path $tools "validate-commercial-registry.mjs") `
  $validator

# ============================================================
# 5. Register scripts.
# ============================================================

$packagePath =
  Join-Path `
    $root `
    "package.json"

Backup $packagePath

$temp =
  Join-Path `
    $env:TEMP `
    "hibeya-phase007f-package.cjs"

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

pkg.scripts["assets:runtime:migrate"] =
  "node tools/assets/migrate-runtime-metadata.mjs";

pkg.scripts["assets:runtime:compile"] =
  "node tools/assets/compile-commercial-registry.mjs";

pkg.scripts["assets:runtime:check"] =
  "node tools/assets/compile-commercial-registry.mjs --check";

pkg.scripts["assets:runtime:validate"] =
  "node tools/assets/validate-commercial-registry.mjs";

pkg.scripts["assets:runtime:qa"] =
  "pnpm assets:runtime:check && pnpm assets:runtime:validate && pnpm assets:commercial:validate";

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
# 6. Run migration + compile + full QA.
# ============================================================

Run `
  "Migrate approved runtime metadata" `
  "pnpm assets:runtime:migrate"

Run `
  "Compile commercial runtime registry" `
  "pnpm assets:runtime:compile"

Run `
  "Commercial registry reproducibility check" `
  "pnpm assets:runtime:check"

Run `
  "Commercial runtime registry validation" `
  "pnpm assets:runtime:validate"

Write-Host ""
Write-Host "NOTE: Global commercial asset gate intentionally deferred in Phase 007F." -ForegroundColor Yellow
Write-Host "Reason: prototype learner-core hibiscus assets are not yet approved for commercial release." -ForegroundColor Yellow
Write-Host "Phase 007F validates only approved assets entering the manifest-driven runtime registry." -ForegroundColor Yellow

Run `
  "Asset family QA" `
  "pnpm assets:families:qa"

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
    "Stage Phase 007F" `
    "git add assets/manifests tools/assets packages/assets/src/commercial.ts packages/assets/src/generated/commercialRegistry.generated.ts package.json"

  Run `
    "Commit Phase 007F" `
    'git commit -m "feat: compile commercial asset registry from provenance"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007F: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Commercial runtime registration is now manifest-driven." -ForegroundColor Cyan
Write-Host "No artwork was changed in this phase." -ForegroundColor Cyan
