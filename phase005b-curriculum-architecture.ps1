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
  $stdout = Join-Path $logsRoot "phase005b-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase005b-$timestamp-err.log"

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
    $diagnostic = Join-Path $logsRoot "FAILED-phase005b-$timestamp-$($Name.Replace(' ','-')).log"

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
Write-Host "HIBEYA AKAL BUDI - PHASE 005B" -ForegroundColor Cyan
Write-Host "Curriculum & Skill Architecture" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan


# ============================================================
# 1. Create curriculum-schema package using the existing
#    content-schema package as the compatible workspace template.
# ============================================================

Write-Step "Creating @akal-budi/curriculum-schema package"

$contentSchemaPackagePath =
  Join-Path $repoRoot "packages\content-schema\package.json"

$contentSchemaTsconfigPath =
  Join-Path $repoRoot "packages\content-schema\tsconfig.json"

if (-not (Test-Path $contentSchemaPackagePath)) {
  throw "packages\content-schema\package.json is required as the workspace template."
}

if (-not (Test-Path $contentSchemaTsconfigPath)) {
  throw "packages\content-schema\tsconfig.json is required as the workspace template."
}

$curriculumPackageRoot =
  Join-Path $repoRoot "packages\curriculum-schema"

New-Item `
  -ItemType Directory `
  -Force `
  -Path (Join-Path $curriculumPackageRoot "src\__tests__") `
  | Out-Null


$sourcePackage =
  Get-Content $contentSchemaPackagePath -Raw |
  ConvertFrom-Json

$sourcePackage.name =
  "@akal-budi/curriculum-schema"

$curriculumPackageText =
  $sourcePackage |
  ConvertTo-Json -Depth 100

Write-Utf8NoBom `
  -Path (Join-Path $curriculumPackageRoot "package.json") `
  -Content $curriculumPackageText


Copy-Item `
  $contentSchemaTsconfigPath `
  (Join-Path $curriculumPackageRoot "tsconfig.json") `
  -Force


# ============================================================
# 2. Curriculum + skill domain schema.
# ============================================================

Write-Step "Installing curriculum and skill schemas"

$schemaSource = @'
import {
  z
} from "zod";


export const CurriculumStatusSchema =
  z.enum([
    "draft",
    "source-verified",
    "mapped",
    "educator-reviewed",
    "approved",
    "published",
    "superseded"
  ]);


export type CurriculumStatus =
  z.infer<
    typeof CurriculumStatusSchema
  >;


export const CurriculumAuthoritySchema =
  z.object({
    id:
      z.string().min(1),

    name:
      z.string().min(1),

    countryCode:
      z.string()
        .length(2)
        .transform(
          value =>
            value.toUpperCase()
        )
  });


export type CurriculumAuthority =
  z.infer<
    typeof CurriculumAuthoritySchema
  >;


export const CurriculumVersionSchema =
  z.object({
    id:
      z.string().min(1),

    authorityId:
      z.string().min(1),

    frameworkId:
      z.string().min(1),

    edition:
      z.string().min(1),

    effectiveFrom:
      z.string().datetime(),

    effectiveTo:
      z.string()
        .datetime()
        .nullable()
        .default(
          null
        ),

    status:
      CurriculumStatusSchema,

    sourceIds:
      z.array(
        z.string().min(1)
      )
  });


export type CurriculumVersion =
  z.infer<
    typeof CurriculumVersionSchema
  >;


export const EducationLevelSchema =
  z.object({
    id:
      z.string().min(1),

    label:
      z.object({
        ms:
          z.string().min(1),

        en:
          z.string().min(1)
      }),

    order:
      z.number()
        .int()
        .nonnegative()
  });


export type EducationLevel =
  z.infer<
    typeof EducationLevelSchema
  >;


export const SubjectSchema =
  z.object({
    id:
      z.string().min(1),

    label:
      z.object({
        ms:
          z.string().min(1),

        en:
          z.string().min(1)
      })
  });


export type Subject =
  z.infer<
    typeof SubjectSchema
  >;


export const StrandSchema =
  z.object({
    id:
      z.string().min(1),

    subjectId:
      z.string().min(1),

    label:
      z.object({
        ms:
          z.string().min(1),

        en:
          z.string().min(1)
      })
  });


export type Strand =
  z.infer<
    typeof StrandSchema
  >;


export const CurriculumStandardSchema =
  z.object({
    id:
      z.string().min(1),

    curriculumVersionId:
      z.string().min(1),

    levelId:
      z.string().min(1),

    subjectId:
      z.string().min(1),

    strandId:
      z.string()
        .min(1)
        .nullable(),

    parentStandardId:
      z.string()
        .min(1)
        .nullable(),

    code:
      z.string().min(1),

    type:
      z.enum([
        "content-standard",
        "learning-standard",
        "other"
      ]),

    description:
      z.object({
        ms:
          z.string().min(1),

        en:
          z.string()
            .min(1)
            .nullable()
      }),

    status:
      CurriculumStatusSchema
  });


export type CurriculumStandard =
  z.infer<
    typeof CurriculumStandardSchema
  >;


export const SkillSchema =
  z.object({
    id:
      z.string()
        .min(1)
        .regex(
          /^[a-z0-9][a-z0-9-]*$/
        ),

    label:
      z.object({
        ms:
          z.string().min(1),

        en:
          z.string().min(1)
      }),

    description:
      z.object({
        ms:
          z.string().min(1),

        en:
          z.string().min(1)
      }),

    domain:
      z.string().min(1),

    active:
      z.boolean()
  });


export type Skill =
  z.infer<
    typeof SkillSchema
  >;


export const SkillPrerequisiteSchema =
  z.object({
    skillId:
      z.string().min(1),

    prerequisiteSkillId:
      z.string().min(1),

    strength:
      z.enum([
        "required",
        "recommended"
      ])
  })
  .refine(
    value =>
      value.skillId !==
      value.prerequisiteSkillId,
    {
      message:
        "A skill cannot require itself."
    }
  );


export type SkillPrerequisite =
  z.infer<
    typeof SkillPrerequisiteSchema
  >;


export const ActivitySkillMappingSchema =
  z.object({
    skillId:
      z.string().min(1),

    role:
      z.enum([
        "primary",
        "supporting"
      ]),

    weight:
      z.number()
        .positive()
        .max(1)
  });


export type ActivitySkillMapping =
  z.infer<
    typeof ActivitySkillMappingSchema
  >;


export const ActivityCurriculumMappingSchema =
  z.object({
    curriculumVersionId:
      z.string().min(1),

    standardId:
      z.string().min(1),

    alignment:
      z.enum([
        "direct",
        "supporting"
      ]),

    reviewStatus:
      z.enum([
        "draft",
        "verified"
      ]),

    reviewedBy:
      z.string()
        .min(1)
        .nullable(),

    reviewedAt:
      z.string()
        .datetime()
        .nullable()
  });


export type ActivityCurriculumMapping =
  z.infer<
    typeof ActivityCurriculumMappingSchema
  >;


export const CurriculumSourceSchema =
  z.object({
    id:
      z.string().min(1),

    authorityId:
      z.string().min(1),

    title:
      z.string().min(1),

    edition:
      z.string()
        .min(1)
        .nullable(),

    effectiveDate:
      z.string()
        .datetime()
        .nullable(),

    sourceUrl:
      z.string().url(),

    retrievedAt:
      z.string().datetime(),

    sha256:
      z.string()
        .regex(
          /^[a-f0-9]{64}$/
        ),

    reviewStatus:
      z.enum([
        "unverified",
        "verified"
      ])
  });


export type CurriculumSource =
  z.infer<
    typeof CurriculumSourceSchema
  >;


export const CurriculumPackSchema =
  z.object({
    id:
      z.string().min(1),

    authority:
      CurriculumAuthoritySchema,

    version:
      CurriculumVersionSchema,

    levels:
      z.array(
        EducationLevelSchema
      ),

    subjects:
      z.array(
        SubjectSchema
      ),

    strands:
      z.array(
        StrandSchema
      ),

    standards:
      z.array(
        CurriculumStandardSchema
      ),

    sources:
      z.array(
        CurriculumSourceSchema
      )
  });


export type CurriculumPack =
  z.infer<
    typeof CurriculumPackSchema
  >;
'@

Write-Utf8NoBom `
  -Path (Join-Path $curriculumPackageRoot "src\index.ts") `
  -Content $schemaSource


# ============================================================
# 3. Tests.
# ============================================================

Write-Step "Creating curriculum-schema tests"

$schemaTests = @'
import {
  describe,
  expect,
  it
} from "vitest";

import {
  ActivityCurriculumMappingSchema,
  ActivitySkillMappingSchema,
  SkillPrerequisiteSchema,
  SkillSchema
} from "../index";


describe(
  "curriculum schema",
  () => {

    it(
      "accepts a valid generic skill",
      () => {

        const skill =
          SkillSchema.parse({
            id:
              "colour-recognition",

            label: {
              ms:
                "Pengecaman warna",

              en:
                "Colour recognition"
            },

            description: {
              ms:
                "Mengenal dan membezakan warna.",

              en:
                "Recognise and distinguish colours."
            },

            domain:
              "visual-cognition",

            active:
              true
          });


        expect(
          skill.id
        ).toBe(
          "colour-recognition"
        );
      }
    );


    it(
      "rejects a self prerequisite",
      () => {

        expect(
          () =>
            SkillPrerequisiteSchema.parse({
              skillId:
                "colour-recognition",

              prerequisiteSkillId:
                "colour-recognition",

              strength:
                "required"
            })
        ).toThrow();
      }
    );


    it(
      "supports weighted activity skill mappings",
      () => {

        expect(
          ActivitySkillMappingSchema.parse({
            skillId:
              "colour-recognition",

            role:
              "primary",

            weight:
              1
          })
        ).toEqual({
          skillId:
            "colour-recognition",

          role:
            "primary",

          weight:
            1
        });
      }
    );


    it(
      "keeps curriculum mappings reviewable",
      () => {

        expect(
          ActivityCurriculumMappingSchema.parse({
            curriculumVersionId:
              "example-version",

            standardId:
              "example-standard",

            alignment:
              "direct",

            reviewStatus:
              "draft",

            reviewedBy:
              null,

            reviewedAt:
              null
          })
        ).toMatchObject({
          reviewStatus:
            "draft"
        });
      }
    );

  }
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $curriculumPackageRoot "src\__tests__\curriculum.schema.test.ts") `
  -Content $schemaTests


# ============================================================
# 4. Canonical skill graph source of truth.
# ============================================================

Write-Step "Creating canonical skill graph"

$skillGraphPath =
  Join-Path $repoRoot "content\curriculum\skill-graph.json"

$skillGraph = @'
{
  "version": 1,
  "skills": [
    {
      "id": "colour-recognition",
      "label": {
        "ms": "Pengecaman warna",
        "en": "Colour recognition"
      },
      "description": {
        "ms": "Mengenal dan membezakan warna yang dipersembahkan secara visual.",
        "en": "Recognise and distinguish visually presented colours."
      },
      "domain": "visual-cognition",
      "active": true
    },
    {
      "id": "visual-discrimination",
      "label": {
        "ms": "Diskriminasi visual",
        "en": "Visual discrimination"
      },
      "description": {
        "ms": "Membezakan ciri visual antara beberapa pilihan.",
        "en": "Distinguish visual features between choices."
      },
      "domain": "visual-cognition",
      "active": true
    }
  ],
  "prerequisites": []
}
'@

Write-Utf8NoBom `
  -Path $skillGraphPath `
  -Content $skillGraph


# ============================================================
# 5. Extend current manifests with explicit skill mappings and
#    empty curriculum mappings. No KPM claims are invented.
# ============================================================

Write-Step "Extending manifests for curriculum-ready metadata"

$manifestDir =
  Join-Path $repoRoot "content\activity-manifests"

$manifestFiles =
  Get-ChildItem `
    -Path $manifestDir `
    -Filter "*.json" `
    -File

foreach ($file in $manifestFiles) {

  Backup-File $file.FullName

  $manifest =
    Get-Content $file.FullName -Raw |
    ConvertFrom-Json

  if (
    -not (
      $manifest.PSObject.Properties.Name -contains
      "curriculumMappings"
    )
  ) {
    $manifest |
      Add-Member `
        -NotePropertyName "curriculumMappings" `
        -NotePropertyValue @()
  }

  if (
    -not (
      $manifest.PSObject.Properties.Name -contains
      "skillMappings"
    )
  ) {
    $skillMappings =
      @()

    $activitySkills =
      @(
        $manifest.activity.skills
      )

    for (
      $index = 0;
      $index -lt $activitySkills.Count;
      $index++
    ) {
      $skillMappings +=
        [pscustomobject]@{
          skillId =
            [string]$activitySkills[$index]

          role =
            if ($index -eq 0) {
              "primary"
            }
            else {
              "supporting"
            }

          weight =
            if ($index -eq 0) {
              1
            }
            else {
              0.5
            }
        }
    }

    $manifest |
      Add-Member `
        -NotePropertyName "skillMappings" `
        -NotePropertyValue $skillMappings
  }

  $manifestText =
    $manifest |
    ConvertTo-Json -Depth 100

  Write-Utf8NoBom `
    -Path $file.FullName `
    -Content $manifestText
}


# ============================================================
# 6. Curriculum validator.
# ============================================================

Write-Step "Installing curriculum validator"

$curriculumToolsRoot =
  Join-Path $repoRoot "tools\curriculum"

New-Item `
  -ItemType Directory `
  -Force `
  -Path $curriculumToolsRoot `
  | Out-Null

$validator = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const repoRoot =
  process.cwd();


function fail(
  message
) {
  console.error(
    `CURRICULUM VALIDATION ERROR: ${message}`
  );

  process.exitCode =
    1;
}


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


const graph =
  readJson(
    "content/curriculum/skill-graph.json"
  );


if (
  !Array.isArray(
    graph.skills
  )
) {
  fail(
    "skill-graph.json must contain skills[]"
  );
}


if (
  !Array.isArray(
    graph.prerequisites
  )
) {
  fail(
    "skill-graph.json must contain prerequisites[]"
  );
}


const skillIds =
  graph.skills.map(
    skill =>
      skill.id
  );


const skillIdSet =
  new Set(
    skillIds
  );


if (
  skillIdSet.size !==
  skillIds.length
) {
  fail(
    "Duplicate skill IDs are not allowed."
  );
}


for (
  const edge
  of graph.prerequisites
) {
  if (
    !skillIdSet.has(
      edge.skillId
    )
  ) {
    fail(
      `Unknown skillId in prerequisite: ${edge.skillId}`
    );
  }


  if (
    !skillIdSet.has(
      edge.prerequisiteSkillId
    )
  ) {
    fail(
      `Unknown prerequisiteSkillId: ${edge.prerequisiteSkillId}`
    );
  }


  if (
    edge.skillId ===
    edge.prerequisiteSkillId
  ) {
    fail(
      `Self prerequisite is forbidden: ${edge.skillId}`
    );
  }
}


/*
 * Cycle detection.
 */
const adjacency =
  new Map();


for (
  const skillId
  of skillIds
) {
  adjacency.set(
    skillId,
    []
  );
}


for (
  const edge
  of graph.prerequisites
) {
  adjacency
    .get(
      edge.prerequisiteSkillId
    )
    .push(
      edge.skillId
    );
}


const visiting =
  new Set();

const visited =
  new Set();


function visit(
  skillId
) {
  if (
    visiting.has(
      skillId
    )
  ) {
    fail(
      `Skill prerequisite cycle detected at ${skillId}`
    );

    return;
  }


  if (
    visited.has(
      skillId
    )
  ) {
    return;
  }


  visiting.add(
    skillId
  );


  for (
    const next
    of adjacency.get(
      skillId
    ) ??
    []
  ) {
    visit(
      next
    );
  }


  visiting.delete(
    skillId
  );

  visited.add(
    skillId
  );
}


for (
  const skillId
  of skillIds
) {
  visit(
    skillId
  );
}


/*
 * Validate every activity manifest against the canonical skill graph.
 */
const manifestDir =
  path.join(
    repoRoot,
    "content",
    "activity-manifests"
  );


const manifestFiles =
  fs.readdirSync(
    manifestDir
  )
    .filter(
      filename =>
        filename.endsWith(
          ".json"
        )
    )
    .sort();


for (
  const filename
  of manifestFiles
) {
  const manifest =
    readJson(
      path.join(
        "content",
        "activity-manifests",
        filename
      )
    );


  if (
    !Array.isArray(
      manifest.skillMappings
    )
  ) {
    fail(
      `${filename}: skillMappings[] is required`
    );

    continue;
  }


  if (
    !Array.isArray(
      manifest.curriculumMappings
    )
  ) {
    fail(
      `${filename}: curriculumMappings[] is required`
    );
  }


  for (
    const mapping
    of manifest.skillMappings
  ) {
    if (
      !skillIdSet.has(
        mapping.skillId
      )
    ) {
      fail(
        `${filename}: unknown skill ${mapping.skillId}`
      );
    }


    if (
      ![
        "primary",
        "supporting"
      ].includes(
        mapping.role
      )
    ) {
      fail(
        `${filename}: invalid skill role ${mapping.role}`
      );
    }


    if (
      typeof mapping.weight !==
        "number" ||
      mapping.weight <=
        0 ||
      mapping.weight >
        1
    ) {
      fail(
        `${filename}: skill weight must be > 0 and <= 1`
      );
    }
  }


  /*
   * Curriculum mappings remain empty until a versioned,
   * source-verified curriculum pack exists.
   * Draft mappings may exist later, but must never pretend to
   * be verified without review metadata.
   */
  for (
    const mapping
    of manifest.curriculumMappings
  ) {
    if (
      mapping.reviewStatus ===
        "verified" &&
      (
        !mapping.reviewedBy ||
        !mapping.reviewedAt
      )
    ) {
      fail(
        `${filename}: verified curriculum mapping requires reviewedBy and reviewedAt`
      );
    }
  }
}


if (
  process.exitCode ===
  1
) {
  process.exit(1);
}


console.log(
  `CURRICULUM VALIDATION: PASS (${skillIds.length} skills, ${manifestFiles.length} manifests)`
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $curriculumToolsRoot "validate.mjs") `
  -Content $validator


# ============================================================
# 7. Architecture documentation.
# ============================================================

Write-Step "Writing curriculum architecture specification"

$architectureDoc = @'
# HIBEYA Akal Budi — Curriculum & Skill Architecture

## Objective

Akal Budi must support multiple curricula, subjects and education levels without creating subject-specific application architecture.

The runtime must remain generic.

Examples such as Jawi, Mathematics, Bahasa Melayu or preschool learning are content domains, not separate applications or separate progress engines.

## Core model

```text
Curriculum Authority
  -> Curriculum Version
    -> Education Level
      -> Subject
        -> Strand
          -> Standard

Skill
  -> prerequisite relationships

Activity
  -> ActivitySkillMapping[]
  -> ActivityCurriculumMapping[]
```

## Separation of concerns

### Curriculum standards

Represent what an external curriculum authority specifies.

They are:

- versioned;
- source-backed;
- reviewable;
- supersedable.

### Skills

Represent reusable learner capabilities.

Skills are curriculum-independent where possible.

For example:

```text
colour-recognition
visual-discrimination
jawi-letter-recognition
word-decoding
quantity-comparison
```

A skill may support several curricula.

### Activities

Activities teach or observe skills.

An activity may map to zero, one or several curriculum standards.

A new activity is not allowed to invent an official curriculum mapping.

## Curriculum claims

A production claim such as "aligned with KPM" requires:

1. a source-verified curriculum version;
2. source provenance;
3. a reviewed standard mapping;
4. review metadata;
5. a non-superseded curriculum version.

Empty curriculum mappings are valid.

Unverified curriculum claims are not.

## Skill graph

Skill prerequisites form a directed acyclic graph.

Example:

```text
letter-recognition
        |
        v
letter-discrimination
        |
        v
letter-joining
        |
        v
word-reading
```

The graph must remain free of cycles.

## Learner model — future

The architecture is designed to support:

```text
Learner Profile
  + Curriculum Path
  + Skill State
  + Activity History
  + Accessibility
        |
        v
Recommendation Engine
        |
        v
Activity
```

Adaptive recommendation is intentionally not implemented in Phase 005B.

## Data ownership

Curriculum source documents and standards are governed content.

Learner progress is runtime data.

They must not be stored or versioned in the same way.

## Commercial scalability

Do not create:

```text
jawi_progress
math_progress
english_progress
```

Use generic:

```text
learner_skill_state
activity_attempt
curriculum_enrolment
```

Subject-specific behaviour belongs in content and mechanic plugins.
'@

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot "CURRICULUM_ARCHITECTURE.md") `
  -Content $architectureDoc


# ============================================================
# 8. Add root automation commands.
# ============================================================

Write-Step "Adding curriculum automation commands"

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
    -NotePropertyName "curriculum:validate" `
    -NotePropertyValue "node tools/curriculum/validate.mjs" `
    -Force

$rootPackage.scripts |
  Add-Member `
    -NotePropertyName "content:check" `
    -NotePropertyValue "node tools/content-compiler/compile.mjs --check" `
    -Force

$rootPackageText =
  $rootPackage |
  ConvertTo-Json -Depth 100

Write-Utf8NoBom `
  -Path $packagePath `
  -Content $rootPackageText


# ============================================================
# 9. Install workspace dependencies and run all gates.
# ============================================================

Invoke-Native `
  -Name "Frozen workspace install" `
  -Command "pnpm install --lockfile-only"

Invoke-Native `
  -Name "Curriculum validation" `
  -Command "pnpm curriculum:validate"

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
    -Command "git add packages/curriculum-schema content/curriculum content/activity-manifests tools/curriculum CURRICULUM_ARCHITECTURE.md package.json pnpm-lock.yaml"

  Invoke-Native `
    -Name "Git commit" `
    -Command 'git commit -m "feat: add curriculum and skill architecture"'
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 005B: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "No official curriculum standards were invented or populated." -ForegroundColor Yellow
Write-Host "Next: Phase 005C Curriculum Source & Review Pipeline." -ForegroundColor Cyan
