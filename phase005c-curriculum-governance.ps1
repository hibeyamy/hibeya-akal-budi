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
  $stdout = Join-Path $logsRoot "phase005c-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase005c-$timestamp-err.log"

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
    $diagnostic = Join-Path $logsRoot "FAILED-phase005c-$timestamp-$($Name.Replace(' ','-')).log"

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
Write-Host "HIBEYA AKAL BUDI - PHASE 005C" -ForegroundColor Cyan
Write-Host "Curriculum Source & Review Pipeline" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan


$curriculumRoot = Join-Path $repoRoot "content\curriculum"
$sourceCacheRoot = Join-Path $curriculumRoot "source-cache"
$toolRoot = Join-Path $repoRoot "tools\curriculum"

New-Item -ItemType Directory -Force -Path $curriculumRoot | Out-Null
New-Item -ItemType Directory -Force -Path $sourceCacheRoot | Out-Null
New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null


# ============================================================
# 1. Source registry.
# Only metadata and official URLs are committed.
# Source documents themselves stay outside Git.
# ============================================================

Write-Step "Creating curriculum source registry"

$registryPath = Join-Path $curriculumRoot "source-registry.json"

$registry = @'
{
  "version": 1,
  "authorities": [
    {
      "id": "kpm-my",
      "name": "Kementerian Pendidikan Malaysia",
      "countryCode": "MY",
      "officialDomains": [
        "moe.gov.my"
      ]
    }
  ],
  "sources": [
    {
      "id": "kpm-kssr-bm-bi-tahap1-penjajaran-edisi3-2025",
      "authorityId": "kpm-my",
      "title": "Surat Siaran KPM Bil. 1 Tahun 2025: Pelaksanaan Dokumen Penjajaran Kurikulum Standard Sekolah Rendah (Semakan 2017) Edisi 3 Bagi Mata Pelajaran Bahasa Melayu Dan Bahasa Inggeris Tahap 1",
      "sourceType": "official-web-page",
      "sourceUrl": "https://www.moe.gov.my/surat-siaran-kpm-bil-1-tahun-2025-pelaksanaan-dokumen-penjajaran-kurikulum-standard-sekolah-rendah-semakan-2017",
      "publicationDate": "2025-03-26",
      "retrievedDate": "2026-08-21",
      "verificationStatus": "metadata-verified",
      "documentSha256": null,
      "notes": "Official KPM page verified. Do not treat as a fully captured curriculum document until the linked document is locally captured and hashed."
    },
    {
      "id": "kpm-kurikulum-persekolahan-2027",
      "authorityId": "kpm-my",
      "title": "Kurikulum Persekolahan 2027",
      "sourceType": "official-web-page",
      "sourceUrl": "https://www.moe.gov.my/kurikulum-persekolahan-2027",
      "publicationDate": null,
      "retrievedDate": "2026-08-21",
      "verificationStatus": "metadata-verified",
      "documentSha256": null,
      "notes": "Official KPM page verified. Curriculum content is not copied into the repository."
    },
    {
      "id": "kpm-jawi-bm-sjk-tahun4-2019",
      "authorityId": "kpm-my",
      "title": "Surat Siaran KPM Bil. 16 Tahun 2019: Pelaksanaan Pengenalan Tulisan Jawi Dalam Kurikulum Mata Pelajaran Bahasa Melayu Untuk Murid Tahun 4 Sekolah Jenis Kebangsaan Mulai Tahun 2020",
      "sourceType": "official-document",
      "sourceUrl": "https://www.moe.gov.my/storage/files/shares/pekeliling_dan_garis_panduan/surat_siaran/bahagian-pengurusan-sekolah-harian/SS%20Bil%2016%20Pelaksanaan%20Pengenalan%20Tulisan%20Jawi%20Dalam%20Kurikulum%20Mata%20Pelajaran%20Bahasa%20Melayu%20Tahun%202020.pdf?_t=1686283878",
      "publicationDate": "2019-12-20",
      "retrievedDate": "2026-08-21",
      "verificationStatus": "metadata-verified",
      "documentSha256": null,
      "notes": "Official KPM document URL verified. Full content is not committed; a local capture must be hashed before document-level verification."
    }
  ]
}
'@

Write-Utf8NoBom -Path $registryPath -Content $registry


# ============================================================
# 2. Review queue.
# ============================================================

Write-Step "Creating curriculum review queue"

$reviewQueuePath = Join-Path $curriculumRoot "review-queue.json"

$reviewQueue = @'
{
  "version": 1,
  "items": []
}
'@

if (-not (Test-Path $reviewQueuePath)) {
  Write-Utf8NoBom -Path $reviewQueuePath -Content $reviewQueue
}


# ============================================================
# 3. Source validator.
# ============================================================

Write-Step "Installing source-registry validator"

$sourceValidator = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const repoRoot =
  process.cwd();


function readJson(
  relativePath
) {
  return JSON.parse(
    fs.readFileSync(
      path.join(
        repoRoot,
        relativePath
      ),
      "utf8"
    )
  );
}


const registry =
  readJson(
    "content/curriculum/source-registry.json"
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
    `SOURCE REGISTRY ERROR: ${message}`
  );
}


if (
  !Array.isArray(
    registry.authorities
  )
) {
  fail(
    "authorities[] is required"
  );
}


if (
  !Array.isArray(
    registry.sources
  )
) {
  fail(
    "sources[] is required"
  );
}


const authorityMap =
  new Map(
    (
      registry.authorities ??
      []
    )
      .map(
        authority => [
          authority.id,
          authority
        ]
      )
  );


const ids =
  (
    registry.sources ??
    []
  )
    .map(
      source =>
        source.id
    );


if (
  new Set(
    ids
  ).size !==
    ids.length
) {
  fail(
    "Duplicate source IDs are not allowed"
  );
}


for (
  const source
  of registry.sources ??
  []
) {
  const authority =
    authorityMap.get(
      source.authorityId
    );


  if (!authority) {
    fail(
      `${source.id}: unknown authority ${source.authorityId}`
    );

    continue;
  }


  let url;

  try {
    url =
      new URL(
        source.sourceUrl
      );
  }
  catch {
    fail(
      `${source.id}: invalid sourceUrl`
    );

    continue;
  }


  const allowed =
    authority.officialDomains
      .some(
        domain =>
          url.hostname ===
            domain ||
          url.hostname.endsWith(
            `.${domain}`
          )
      );


  if (!allowed) {
    fail(
      `${source.id}: URL is outside the authority's official domains`
    );
  }


  if (
    ![
      "unverified",
      "metadata-verified",
      "document-verified",
      "superseded"
    ].includes(
      source.verificationStatus
    )
  ) {
    fail(
      `${source.id}: invalid verificationStatus`
    );
  }


  if (
    source.verificationStatus ===
      "document-verified"
  ) {
    if (
      typeof source.documentSha256 !==
        "string" ||
      !/^[a-f0-9]{64}$/.test(
        source.documentSha256
      )
    ) {
      fail(
        `${source.id}: document-verified sources require a SHA-256 hash`
      );
    }
  }


  if (
    source.documentSha256 !==
      null &&
    (
      typeof source.documentSha256 !==
        "string" ||
      !/^[a-f0-9]{64}$/.test(
        source.documentSha256
      )
    )
  ) {
    fail(
      `${source.id}: documentSha256 must be null or a lowercase SHA-256 hash`
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
  `CURRICULUM SOURCE REGISTRY: PASS (${registry.sources.length} sources)`
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $toolRoot "validate-sources.mjs") `
  -Content $sourceValidator


# ============================================================
# 4. Local source capture helper.
# Never downloads automatically. User supplies a local official
# document; tool hashes it and stores only the hash in registry.
# ============================================================

Write-Step "Installing local source capture helper"

$captureTool = @'
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const [
  ,
  ,
  sourceId,
  localFile
] =
  process.argv;


if (
  !sourceId ||
  !localFile
) {
  console.error(
    "Usage: node tools/curriculum/capture-source.mjs <source-id> <local-file>"
  );

  process.exit(1);
}


const repoRoot =
  process.cwd();

const registryPath =
  path.join(
    repoRoot,
    "content",
    "curriculum",
    "source-registry.json"
  );

const sourceCacheRoot =
  path.join(
    repoRoot,
    "content",
    "curriculum",
    "source-cache"
  );


const resolvedFile =
  path.resolve(
    localFile
  );


if (
  !fs.existsSync(
    resolvedFile
  )
) {
  console.error(
    `Local source file not found: ${resolvedFile}`
  );

  process.exit(1);
}


const registry =
  JSON.parse(
    fs.readFileSync(
      registryPath,
      "utf8"
    )
  );


const source =
  registry.sources.find(
    item =>
      item.id ===
      sourceId
  );


if (!source) {
  console.error(
    `Unknown source ID: ${sourceId}`
  );

  process.exit(1);
}


const bytes =
  fs.readFileSync(
    resolvedFile
  );


const sha256 =
  crypto
    .createHash(
      "sha256"
    )
    .update(
      bytes
    )
    .digest(
      "hex"
    );


fs.mkdirSync(
  sourceCacheRoot,
  {
    recursive:
      true
  }
);


const extension =
  path.extname(
    resolvedFile
  )
    .toLowerCase();


const cachedFile =
  path.join(
    sourceCacheRoot,
    `${sourceId}${extension}`
  );


fs.copyFileSync(
  resolvedFile,
  cachedFile
);


source.documentSha256 =
  sha256;

source.verificationStatus =
  "document-verified";


fs.writeFileSync(
  registryPath,
  JSON.stringify(
    registry,
    null,
    2
  ) +
  "\n",
  "utf8"
);


console.log(
  `CAPTURED: ${sourceId}`
);

console.log(
  `SHA256: ${sha256}`
);

console.log(
  "The cached source document is local-only and must remain ignored by Git."
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $toolRoot "capture-source.mjs") `
  -Content $captureTool


# ============================================================
# 5. Review queue manager.
# ============================================================

Write-Step "Installing curriculum review workflow helper"

$reviewTool = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const [
  ,
  ,
  command,
  ...args
] =
  process.argv;


const repoRoot =
  process.cwd();

const queuePath =
  path.join(
    repoRoot,
    "content",
    "curriculum",
    "review-queue.json"
  );


const queue =
  JSON.parse(
    fs.readFileSync(
      queuePath,
      "utf8"
    )
  );


function save() {
  fs.writeFileSync(
    queuePath,
    JSON.stringify(
      queue,
      null,
      2
    ) +
    "\n",
    "utf8"
  );
}


if (
  command ===
    "add"
) {
  const [
    mappingId,
    activityId,
    curriculumVersionId,
    standardId
  ] =
    args;


  if (
    !mappingId ||
    !activityId ||
    !curriculumVersionId ||
    !standardId
  ) {
    console.error(
      "Usage: review-mapping.mjs add <mapping-id> <activity-id> <curriculum-version-id> <standard-id>"
    );

    process.exit(1);
  }


  if (
    queue.items.some(
      item =>
        item.id ===
        mappingId
    )
  ) {
    console.error(
      `Review item already exists: ${mappingId}`
    );

    process.exit(1);
  }


  queue.items.push({
    id:
      mappingId,

    activityId,

    curriculumVersionId,

    standardId,

    status:
      "draft",

    reviewer:
      null,

    reviewedAt:
      null,

    notes:
      null
  });


  save();

  console.log(
    `REVIEW ITEM CREATED: ${mappingId}`
  );

  process.exit(0);
}


if (
  command ===
    "approve"
) {
  const [
    mappingId,
    reviewer
  ] =
    args;


  if (
    !mappingId ||
    !reviewer
  ) {
    console.error(
      "Usage: review-mapping.mjs approve <mapping-id> <reviewer>"
    );

    process.exit(1);
  }


  const item =
    queue.items.find(
      candidate =>
        candidate.id ===
        mappingId
    );


  if (!item) {
    console.error(
      `Unknown review item: ${mappingId}`
    );

    process.exit(1);
  }


  item.status =
    "approved";

  item.reviewer =
    reviewer;

  item.reviewedAt =
    new Date()
      .toISOString();


  save();

  console.log(
    `REVIEW ITEM APPROVED: ${mappingId}`
  );

  process.exit(0);
}


if (
  command ===
    "list"
) {
  console.log(
    JSON.stringify(
      queue.items,
      null,
      2
    )
  );

  process.exit(0);
}


console.error(
  "Commands: add | approve | list"
);

process.exit(1);
'@

Write-Utf8NoBom `
  -Path (Join-Path $toolRoot "review-mapping.mjs") `
  -Content $reviewTool


# ============================================================
# 6. Git hygiene: source-cache is local-only.
# ============================================================

Write-Step "Protecting copyrighted source documents from Git"

$gitignorePath = Join-Path $repoRoot ".gitignore"
$gitignore = if (Test-Path $gitignorePath) { Get-Content $gitignorePath -Raw } else { "" }

$ignoreLine = "content/curriculum/source-cache/"

if (-not $gitignore.Contains($ignoreLine)) {
  $gitignore += "`n# Local curriculum source documents - metadata only is committed`n$ignoreLine`n"
  Write-Utf8NoBom -Path $gitignorePath -Content $gitignore
}


# ============================================================
# 7. Governance documentation.
# ============================================================

Write-Step "Writing curriculum governance specification"

$governanceDoc = @'
# HIBEYA Akal Budi — Curriculum Source & Review Governance

## Principle

Akal Budi may use official curriculum documents as factual references, but official source documents are not copied into the product repository.

The repository stores:

- source metadata;
- official source URLs;
- verification status;
- cryptographic document hashes;
- mapping review records.

Local source files remain outside Git.

## Verification levels

### unverified

A source has been proposed but its authority/domain has not been confirmed.

### metadata-verified

The source title and URL have been verified against an official authority domain.

This does not mean the complete document has been captured.

### document-verified

A local copy of the official document has been captured for internal review and its SHA-256 hash is recorded.

The local document remains ignored by Git.

### superseded

A newer curriculum version or official document has replaced the source.

## Curriculum mapping workflow

```text
Official source
    |
    v
metadata-verified
    |
    v
local capture + SHA-256
    |
    v
document-verified
    |
    v
curriculum extraction
    |
    v
human mapping review
    |
    v
approved mapping
    |
    v
production curriculum claim
```

## Copyright boundary

Do not copy substantial curriculum-document text into activity manifests.

Store structured identifiers, short factual labels and original HIBEYA instructional content.

The curriculum source registry provides traceability without making the repository a redistribution channel for source documents.

## Review principle

Automation can:

- validate source-domain provenance;
- calculate hashes;
- validate mapping structure;
- detect missing review metadata.

Automation cannot decide that an activity is pedagogically aligned with an official standard.

That requires explicit human/educator review.
'@

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot "CURRICULUM_GOVERNANCE.md") `
  -Content $governanceDoc


# ============================================================
# 8. Root automation commands.
# ============================================================

Write-Step "Adding source governance commands"

$packagePath = Join-Path $repoRoot "package.json"
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
    -NotePropertyName "curriculum:sources:validate" `
    -NotePropertyValue "node tools/curriculum/validate-sources.mjs" `
    -Force

$rootPackage.scripts |
  Add-Member `
    -NotePropertyName "curriculum:review:list" `
    -NotePropertyValue "node tools/curriculum/review-mapping.mjs list" `
    -Force

$rootPackageText =
  $rootPackage |
  ConvertTo-Json -Depth 100

Write-Utf8NoBom -Path $packagePath -Content $rootPackageText


# ============================================================
# 9. Validation.
# ============================================================

Invoke-Native `
  -Name "Curriculum architecture validation" `
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

if (Test-Path (Join-Path $repoRoot ".env.security.local")) {
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
    -Command "git add content/curriculum/source-registry.json content/curriculum/review-queue.json tools/curriculum/validate-sources.mjs tools/curriculum/capture-source.mjs tools/curriculum/review-mapping.mjs CURRICULUM_GOVERNANCE.md package.json .gitignore"

  Invoke-Native `
    -Name "Git commit" `
    -Command 'git commit -m "feat: add curriculum source governance pipeline"'
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 005C: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Official documents are metadata-tracked but not redistributed." -ForegroundColor Green
Write-Host "Next: Phase 006 Design System Foundation." -ForegroundColor Cyan
