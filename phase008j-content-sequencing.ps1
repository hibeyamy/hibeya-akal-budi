param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008j-content-sequencing-$runId.log"

$compilerPath = Join-Path $root "tools\content-compiler\compile.mjs"
$newActivityPath = Join-Path $root "tools\content-compiler\new-activity.mjs"
$validatorPath = Join-Path $root "tools\content-compiler\validate-sequencing.mjs"
$packagePath = Join-Path $root "package.json"
$manifestDir = Join-Path $root "content\activity-manifests"

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
    if (-not (Test-Path $Path)) {
        return
    }

    $relative = $Path.Substring($root.Length).TrimStart("\")
    $safe = $relative -replace '[\\/:*?"<>|]', '_'

    Copy-Item `
        $Path `
        (Join-Path $backups "$runId-$safe") `
        -Force
}

function Run([string]$Name,[string]$Command) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

    $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $out = Join-Path $logs "phase008j-$stamp-out.log"
    $err = Join-Path $logs "phase008j-$stamp-err.log"

    $p = Start-Process `
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

    if ($p.ExitCode -ne 0) {
        $diag = Join-Path $logs "FAILED-phase008j-$stamp-$($Name.Replace(' ','-')).log"

        WriteText `
            $diag `
            "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

        throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
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
    Write-Host "PHASE 008J: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    Write-Host "Do not make manual source edits unless explicitly requested after log review." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008J" -ForegroundColor Cyan
Write-Host "Manifest-Driven Explicit Content Sequencing" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

foreach ($required in @(
    $compilerPath,
    $newActivityPath,
    $packagePath,
    $manifestDir
)) {
    if (-not (Test-Path $required)) {
        throw "Required Phase 008J dependency missing: $required"
    }
}

# ------------------------------------------------------------------
# Verify exact compiler/helper contracts BEFORE any write.
# ------------------------------------------------------------------

$compiler = Get-Content $compilerPath -Raw
$newActivity = Get-Content $newActivityPath -Raw

foreach ($token in @(
    "function catalogueSource()",
    "manifest.catalogue",
    "export interface PlayableActivity",
    "getPlayableActivitiesForAgeBand",
    "implementationKey"
)) {
    if ($compiler -notmatch [Regex]::Escape($token)) {
        throw "Content compiler contract drifted. Missing token: $token"
    }
}

foreach ($token in @(
    "const manifest = {",
    "catalogue: {",
    "enabled:",
    "ageBands:",
    "implementationKey:"
)) {
    if ($newActivity -notmatch [Regex]::Escape($token)) {
        throw "new-activity helper contract drifted. Missing token: $token"
    }
}

if ($compiler -match 'sequence:\s*\$\{') {
    throw "Compiler already appears sequence-aware. Stop and inspect before applying Phase 008J."
}

$manifestFiles = @(
    Get-ChildItem `
        $manifestDir `
        -File `
        -Filter *.json `
        -ErrorAction Stop |
    Sort-Object Name
)

if ($manifestFiles.Count -eq 0) {
    throw "No activity manifests found."
}

foreach ($file in $manifestFiles) {
    $manifest = Get-Content $file.FullName -Raw | ConvertFrom-Json

    if ($null -eq $manifest.catalogue) {
        throw "$($file.Name): catalogue object missing."
    }

    if ($manifest.catalogue.PSObject.Properties.Name -contains "sequence") {
        throw "$($file.Name): catalogue.sequence already exists. Refusing duplicate migration."
    }
}

Write-Host "PASS: current compiler/helper/manifest contracts verified" -ForegroundColor Green

# ------------------------------------------------------------------
# Backups
# ------------------------------------------------------------------

foreach ($path in @(
    $compilerPath,
    $newActivityPath,
    $packagePath
)) {
    Backup $path
}

foreach ($file in $manifestFiles) {
    Backup $file.FullName
}

# ------------------------------------------------------------------
# Atomic Node editor:
# - sequence metadata added to existing manifests
# - compiler emits sequence and sorts by it
# - new-activity automatically allocates next sequence
# ------------------------------------------------------------------

$editor = Join-Path $env:TEMP "hibeya-phase008j-editor-$runId.cjs"

WriteText $editor @'
const fs = require("fs");
const path = require("path");

const [
  compilerPath,
  newActivityPath,
  packagePath,
  manifestDir
] = process.argv.slice(2);

function read(file) {
  return fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
}

function requireCondition(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const originalCompiler = read(compilerPath);
const originalHelper = read(newActivityPath);
const originalPackage = read(packagePath);

let compiler = originalCompiler;
let helper = originalHelper;
const pkg = JSON.parse(originalPackage);

const manifestFiles =
  fs.readdirSync(manifestDir)
    .filter(file => file.endsWith(".json"))
    .sort();

requireCondition(
  manifestFiles.length > 0,
  "No activity manifests found."
);

const manifests = manifestFiles.map(file => {
  const absolute = path.join(manifestDir, file);
  const manifest = JSON.parse(read(absolute));

  requireCondition(
    manifest.catalogue &&
    typeof manifest.catalogue === "object",
    `${file}: catalogue object missing`
  );

  requireCondition(
    manifest.catalogue.sequence === undefined,
    `${file}: sequence already exists`
  );

  return {
    file,
    absolute,
    manifest
  };
});

// Preserve the currently deterministic manifest order while moving that
// responsibility into explicit data. Gaps of 10 leave room for insertion.
for (let index = 0; index < manifests.length; index += 1) {
  manifests[index].manifest.catalogue.sequence =
    (index + 1) * 10;
}

// ---- compiler: generated catalogue row ----
const rowAnchor =
`      enabled:
        \${Boolean(c.enabled)},

      ageBands:`;

requireCondition(
  compiler.includes(rowAnchor),
  "Compiler row anchor not found."
);

compiler = compiler.replace(
  rowAnchor,
`      enabled:
        \${Boolean(c.enabled)},

      sequence:
        \${c.sequence},

      ageBands:`
);

// ---- compiler: PlayableActivity interface ----
const interfaceAnchor =
`  enabled: boolean;

  ageBands:`;

requireCondition(
  compiler.includes(interfaceAnchor),
  "PlayableActivity interface anchor not found."
);

compiler = compiler.replace(
  interfaceAnchor,
`  enabled: boolean;

  sequence: number;

  ageBands:`
);

// ---- compiler: age-band result ordering ----
const orderingAnchor =
`    )
    .map(
      activity =>
        getPlayableActivity(
          activity.id
        )
    )`;

requireCondition(
  compiler.includes(orderingAnchor),
  "Catalogue ordering anchor not found."
);

compiler = compiler.replace(
  orderingAnchor,
`    )
    .sort(
      (
        left,
        right
      ) =>
        left.sequence -
          right.sequence ||
        left.id.localeCompare(
          right.id
        )
    )
    .map(
      activity =>
        getPlayableActivity(
          activity.id
        )
    )`
);

// ---- new-activity helper: calculate next sequence ----
const manifestAnchor = "const manifest = {";

requireCondition(
  helper.includes(manifestAnchor),
  "new-activity manifest anchor not found."
);

helper = helper.replace(
  manifestAnchor,
`const manifestDirectory =
  path.dirname(
    target
  );

const existingSequences =
  fs.existsSync(
    manifestDirectory
  )
    ? fs.readdirSync(
        manifestDirectory
      )
        .filter(
          file =>
            file.endsWith(
              ".json"
            )
        )
        .map(
          file => {
            try {
              const existing =
                JSON.parse(
                  fs.readFileSync(
                    path.join(
                      manifestDirectory,
                      file
                    ),
                    "utf8"
                  )
                );

              return Number.isInteger(
                existing.catalogue?.sequence
              )
                ? existing.catalogue.sequence
                : 0;
            }
            catch {
              return 0;
            }
          }
        )
    : [];

const nextSequence =
  (
    existingSequences.length
      ? Math.max(
          ...existingSequences
        )
      : 0
  ) +
  10;


const manifest = {`
);

// ---- new-activity helper: write sequence ----
const helperCatalogueAnchor =
`    enabled:
      false,

    ageBands:`;

requireCondition(
  helper.includes(helperCatalogueAnchor),
  "new-activity catalogue anchor not found."
);

helper = helper.replace(
  helperCatalogueAnchor,
`    enabled:
      false,

    sequence:
      nextSequence,

    ageBands:`
);

// ---- package script ----
pkg.scripts ??= {};
pkg.scripts["content:sequence:validate"] =
  "node tools/content-compiler/validate-sequencing.mjs";

// Postconditions before any writes.
requireCondition(
  compiler.includes("sequence: number;"),
  "Compiler sequence interface postcondition failed."
);

requireCondition(
  compiler.includes("left.sequence -"),
  "Compiler ordering postcondition failed."
);

requireCondition(
  helper.includes("const nextSequence ="),
  "new-activity sequence allocator postcondition failed."
);

requireCondition(
  helper.includes("sequence:\n      nextSequence"),
  "new-activity sequence field postcondition failed."
);

// Only after all transforms validate do we write.
fs.writeFileSync(compilerPath, compiler, "utf8");
fs.writeFileSync(newActivityPath, helper, "utf8");
fs.writeFileSync(
  packagePath,
  JSON.stringify(pkg, null, 2) + "\n",
  "utf8"
);

for (const entry of manifests) {
  fs.writeFileSync(
    entry.absolute,
    JSON.stringify(entry.manifest, null, 2) + "\n",
    "utf8"
  );
}

console.log(
  `PASS: sequencing metadata assigned to ${manifests.length} manifests`
);
console.log(
  "PASS: compiler now emits and orders by catalogue.sequence"
);
console.log(
  "PASS: new-activity helper automatically allocates the next sequence"
);
'@

& node `
    $editor `
    $compilerPath `
    $newActivityPath `
    $packagePath `
    $manifestDir

if ($LASTEXITCODE -ne 0) {
    throw "Phase 008J atomic source transformation failed."
}

Remove-Item $editor -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------------
# Durable sequence validator.
# Duplicate sequence values are only invalid when age-band scopes overlap.
# ------------------------------------------------------------------

WriteText $validatorPath @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root =
  process.cwd();

const manifestDir =
  path.join(
    root,
    "content",
    "activity-manifests"
  );

const failures = [];

function fail(message) {
  failures.push(
    message
  );
}

if (
  !fs.existsSync(
    manifestDir
  )
) {
  fail(
    "Activity manifest directory is missing."
  );
}

const entries =
  fs.existsSync(
    manifestDir
  )
    ? fs.readdirSync(
        manifestDir
      )
        .filter(
          file =>
            file.endsWith(
              ".json"
            )
        )
        .sort()
        .map(
          file => {
            const manifest =
              JSON.parse(
                fs.readFileSync(
                  path.join(
                    manifestDir,
                    file
                  ),
                  "utf8"
                )
              );

            return {
              file,
              id:
                manifest.activity?.id,
              enabled:
                manifest.catalogue?.enabled ===
                  true,
              sequence:
                manifest.catalogue?.sequence,
              ageBands:
                Array.isArray(
                  manifest.catalogue?.ageBands
                )
                  ? manifest.catalogue.ageBands
                  : []
            };
          }
        )
    : [];

for (
  const entry
  of entries
) {
  if (
    !Number.isInteger(
      entry.sequence
    ) ||
    entry.sequence <=
      0
  ) {
    fail(
      `${entry.file}: catalogue.sequence must be a positive integer`
    );
  }

  if (
    entry.ageBands.length ===
      0
  ) {
    fail(
      `${entry.file}: catalogue.ageBands must contain at least one age band`
    );
  }
}

for (
  let leftIndex = 0;
  leftIndex <
    entries.length;
  leftIndex +=
    1
) {
  for (
    let rightIndex =
      leftIndex +
      1;
    rightIndex <
      entries.length;
    rightIndex +=
      1
  ) {
    const left =
      entries[leftIndex];

    const right =
      entries[rightIndex];

    if (
      left.sequence !==
        right.sequence
    ) {
      continue;
    }

    const overlapping =
      left.ageBands.filter(
        ageBand =>
          right.ageBands.includes(
            ageBand
          )
      );

    if (
      overlapping.length >
      0
    ) {
      fail(
        `${left.file} and ${right.file}: duplicate sequence ${left.sequence} for overlapping age band(s): ${overlapping.join(", ")}`
      );
    }
  }
}

if (
  failures.length >
    0
) {
  console.error(
    "CONTENT SEQUENCING VALIDATION: FAILED"
  );

  for (
    const failure
    of failures
  ) {
    console.error(
      `- ${failure}`
    );
  }

  process.exit(
    1
  );
}

console.log(
  `CONTENT SEQUENCING VALIDATION: PASS (${entries.length} manifests)`
);
'@

Write-Host "PASS: durable sequencing validator installed" -ForegroundColor Green

# ------------------------------------------------------------------
# Focused gates first.
# ------------------------------------------------------------------

Run `
    "Content sequencing validation" `
    "pnpm content:sequence:validate"

Run `
    "Compile manifest-driven content" `
    "node tools/content-compiler/compile.mjs"

Run `
    "Content compiler reproducibility" `
    "pnpm content:check"

# Verify generated catalogue actually contains and uses sequence.
$cataloguePath = Join-Path $root "packages\content-library\src\catalogue.ts"

if (-not (Test-Path $cataloguePath)) {
    throw "Generated catalogue missing after compilation."
}

$catalogue = Get-Content $cataloguePath -Raw

foreach ($token in @(
    "sequence: number;",
    "left.sequence -",
    "getPlayableActivitiesForAgeBand"
)) {
    if ($catalogue -notmatch [Regex]::Escape($token)) {
        throw "Generated catalogue sequencing postcondition failed. Missing token: $token"
    }
}

Write-Host "PASS: generated catalogue is explicitly sequence-driven" -ForegroundColor Green

Run `
    "Content sequencing validation after compilation" `
    "pnpm content:sequence:validate"

Run `
    "Learner web typecheck" `
    "pnpm --filter learner-web typecheck"

Run `
    "Learner web tests" `
    "pnpm --filter learner-web test"

Run `
    "Repository typecheck" `
    "pnpm typecheck"

Run `
    "All tests" `
    "pnpm test"

Run `
    "Curriculum validation" `
    "pnpm curriculum:validate"

Run `
    "Production build" `
    "pnpm build"

# Browser QA depends on a complete Storybook static build.
Run `
    "Storybook production build" `
    "pnpm storybook:build"

Run `
    "Learner journey regression" `
    "pnpm qa:journey"

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
        "Stage Phase 008J" `
        "git add content/activity-manifests tools/content-compiler packages/content-library/src apps/learner-web/src/features/play/activityRegistry.ts packages/learning-insights/src/activityMetadata.ts package.json"

    Run `
        "Commit Phase 008J" `
        'git commit -m "feat: add manifest-driven activity sequencing"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008J: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Activity order is now explicit content data." -ForegroundColor Cyan
Write-Host "Learner application code remains content-agnostic." -ForegroundColor Cyan
Write-Host "Future new activities receive an automatic sequence value." -ForegroundColor Cyan
Write-Host "No manual intervention is required." -ForegroundColor Cyan
