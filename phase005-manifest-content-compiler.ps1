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
  Copy-Item $Path (Join-Path $backupRoot "$timestamp-$safe") -Force
}

function Invoke-Native {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command
  )

  Write-Step $Name

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logsRoot "phase005-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase005-$timestamp-err.log"

  $process = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @(
      "/d",
      "/s",
      "/c",
      $Command
    ) `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -NoNewWindow `
    -Wait `
    -PassThru

  $outText = ""
  $errText = ""

  if (Test-Path $stdout) {
    $outText = Get-Content $stdout -Raw
    if ($outText) {
      Write-Host $outText
    }
  }

  if (Test-Path $stderr) {
    $errText = Get-Content $stderr -Raw
    if ($errText) {
      Write-Host $errText
    }
  }

  if ($process.ExitCode -ne 0) {
    $diagnostic = Join-Path $logsRoot "FAILED-phase005-$timestamp-$($Name.Replace(' ','-')).log"

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
Write-Host "HIBEYA AKAL BUDI - PHASE 005" -ForegroundColor Cyan
Write-Host "Manifest-driven content compiler" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan


$manifestRoot = Join-Path $repoRoot "content\activity-manifests"
$compilerRoot = Join-Path $repoRoot "tools\content-compiler"

New-Item -ItemType Directory -Force -Path $manifestRoot | Out-Null
New-Item -ItemType Directory -Force -Path $compilerRoot | Out-Null


# ------------------------------------------------------------------
# Back up files that will become generated outputs.
# ------------------------------------------------------------------

$generatedTargets = @(
  "packages\content-library\src\activities\warna-merah-001.ts",
  "packages\content-library\src\activities\warna-bunga-raya-001.ts",
  "packages\content-library\src\catalogue.ts",
  "packages\content-library\src\index.ts",
  "apps\learner-web\src\features\play\activityRegistry.ts",
  "packages\learning-insights\src\activityMetadata.ts"
)

Write-Step "Backing up current generated-target files"

foreach ($relative in $generatedTargets) {
  Backup-File (Join-Path $repoRoot $relative)
}


# ------------------------------------------------------------------
# Manifest: generic red-colour activity.
# ------------------------------------------------------------------

Write-Step "Creating canonical activity manifests"

$warnaMerahManifest = @'
{
  "exportName": "warnaMerah001",
  "activity": {
    "id": "warna-merah-001",
    "version": 2,
    "mechanic": "tap-choice",
    "ageBand": "3-4",
    "domains": ["logic"],
    "skills": [
      "colour-recognition",
      "visual-discrimination"
    ],
    "difficulty": 1,
    "title": {
      "ms": "Cari Warna Merah",
      "en": "Find the Red Colour"
    },
    "instruction": {
      "ms": "Cari buah yang berwarna merah",
      "en": "Find the fruit that is red"
    },
    "options": [
      {
        "id": "apple-red",
        "asset": "apple-red",
        "correct": true
      },
      {
        "id": "apple-green",
        "asset": "apple-green",
        "correct": false
      },
      {
        "id": "banana-yellow",
        "asset": "banana-yellow",
        "correct": false
      }
    ],
    "development": {
      "objectiveIds": [
        "visual-colour-recognition"
      ],
      "rationale": {
        "ms": "Aktiviti ini membantu kanak-kanak membezakan dan mengenal warna melalui pilihan visual yang mudah.",
        "en": "This activity supports basic colour recognition and visual discrimination through simple visual choices."
      },
      "interactionMode": "independent",
      "estimatedMinutes": 2,
      "parentParticipationRecommended": false,
      "offlineExtension": {
        "ms": "Cari tiga benda berwarna merah di sekeliling bersama orang dewasa.",
        "en": "Find three red objects around you with an adult."
      },
      "researchRefs": [
        "AB-RESEARCH-EARLY-PLAY-001"
      ]
    },
    "wellbeing": {
      "sensoryLoad": "low",
      "rewardIntensity": 1,
      "animationIntensity": 0,
      "audioIntensity": 0,
      "usesCountdownPressure": false,
      "usesLossAversion": false,
      "usesStreakPressure": false,
      "usesInfinitePlay": false,
      "usesBehaviouralAds": false,
      "penalisesMistakes": false
    },
    "malaysia": {
      "relevance": "neutral",
      "elements": [],
      "culturalReviewRequired": false
    },
    "accessibility": {
      "reducedMotionSafe": true,
      "requiresReading": false,
      "requiresAudio": false,
      "colourIsLearningTarget": true,
      "largeTouchTargets": true,
      "alternativeInstructionAvailable": true
    },
    "provenance": {
      "type": "original",
      "creator": "HIBEYA",
      "assetSourceRefs": [],
      "originalityReviewed": true,
      "culturalReviewed": true,
      "reviewedBy": "HIBEYA internal review",
      "reviewedAt": "2026-08-20T00:00:00.000Z"
    },
    "metadata": {
      "estimatedSeconds": 120,
      "active": true
    }
  },
  "catalogue": {
    "blueprintId": "warna-bunga-raya",
    "enabled": true,
    "ageBands": ["3-4"],
    "titleMs": "Cari Warna Merah",
    "titleEn": "Find the Red Colour",
    "implementationKey": "colour-choice-v1"
  },
  "learningInsights": {
    "objectives": [
      "colour-recognition",
      "visual-matching",
      "malay-vocabulary"
    ],
    "malaysiaElements": []
  }
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $manifestRoot "warna-merah-001.json") `
  -Content $warnaMerahManifest


# ------------------------------------------------------------------
# Manifest: Malaysian Bunga Raya activity.
# ------------------------------------------------------------------

$warnaBungaRayaManifest = @'
{
  "exportName": "warnaBungaRaya001",
  "activity": {
    "id": "warna-bunga-raya-001",
    "version": 1,
    "mechanic": "tap-choice",
    "ageBand": "3-4",
    "domains": ["logic"],
    "skills": [
      "colour-recognition",
      "visual-discrimination"
    ],
    "difficulty": 1,
    "title": {
      "ms": "Mana Bunga Raya Merah?",
      "en": "Which Hibiscus Is Red?"
    },
    "instruction": {
      "ms": "Cari bunga raya yang berwarna merah",
      "en": "Find the hibiscus that is red"
    },
    "options": [
      {
        "id": "hibiscus-red",
        "asset": "hibiscus-red",
        "correct": true
      },
      {
        "id": "hibiscus-yellow",
        "asset": "hibiscus-yellow",
        "correct": false
      },
      {
        "id": "hibiscus-purple",
        "asset": "hibiscus-purple",
        "correct": false
      }
    ],
    "development": {
      "objectiveIds": [
        "visual-colour-recognition",
        "local-environment-awareness"
      ],
      "rationale": {
        "ms": "Aktiviti ini memberi peluang kepada kanak-kanak mengenal warna merah melalui bunga raya sebagai unsur tempatan yang dekat dengan identiti Malaysia.",
        "en": "This activity gives children an opportunity to recognise red using the hibiscus as a locally relevant Malaysian element."
      },
      "interactionMode": "independent",
      "estimatedMinutes": 2,
      "parentParticipationRecommended": false,
      "offlineExtension": {
        "ms": "Jika ada tumbuhan berbunga berdekatan, lihat bersama orang dewasa dan berbual tentang warna bunganya.",
        "en": "If there are flowering plants nearby, look at them with an adult and talk about their colours."
      },
      "researchRefs": [
        "AB-RESEARCH-EARLY-PLAY-001"
      ]
    },
    "wellbeing": {
      "sensoryLoad": "low",
      "rewardIntensity": 1,
      "animationIntensity": 0,
      "audioIntensity": 0,
      "usesCountdownPressure": false,
      "usesLossAversion": false,
      "usesStreakPressure": false,
      "usesInfinitePlay": false,
      "usesBehaviouralAds": false,
      "penalisesMistakes": false
    },
    "malaysia": {
      "relevance": "core",
      "elements": [
        "bunga raya"
      ],
      "culturalReviewRequired": false
    },
    "accessibility": {
      "reducedMotionSafe": true,
      "requiresReading": false,
      "requiresAudio": false,
      "colourIsLearningTarget": true,
      "largeTouchTargets": true,
      "alternativeInstructionAvailable": true
    },
    "provenance": {
      "type": "original",
      "creator": "HIBEYA",
      "assetSourceRefs": [],
      "originalityReviewed": true,
      "culturalReviewed": true,
      "reviewedBy": "HIBEYA internal review",
      "reviewedAt": "2026-08-20T00:00:00.000Z"
    },
    "metadata": {
      "estimatedSeconds": 90,
      "active": true
    }
  },
  "catalogue": {
    "blueprintId": "warna-bunga-raya",
    "enabled": true,
    "ageBands": ["3-4"],
    "titleMs": "Mana Bunga Raya Merah?",
    "titleEn": "Which Hibiscus Is Red?",
    "implementationKey": "colour-choice-v1"
  },
  "learningInsights": {
    "objectives": [
      "colour-recognition",
      "visual-matching",
      "malay-vocabulary",
      "malaysian-context"
    ],
    "malaysiaElements": [
      "bunga raya"
    ]
  }
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $manifestRoot "warna-bunga-raya-001.json") `
  -Content $warnaBungaRayaManifest


# ------------------------------------------------------------------
# Compiler.
# ------------------------------------------------------------------

Write-Step "Installing manifest compiler"

$compiler = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const repoRoot =
  process.cwd();

const manifestRoot =
  path.join(
    repoRoot,
    "content",
    "activity-manifests"
  );


function fail(message) {
  console.error(
    `CONTENT COMPILER ERROR: ${message}`
  );

  process.exit(1);
}


function readJson(filePath) {
  try {
    return JSON.parse(
      fs.readFileSync(
        filePath,
        "utf8"
      )
    );
  } catch (error) {
    fail(
      `Cannot parse ${filePath}: ${error.message}`
    );
  }
}


function assert(
  condition,
  message
) {
  if (!condition) {
    fail(message);
  }
}


function assertString(
  value,
  label
) {
  assert(
    typeof value ===
      "string" &&
    value.length >
      0,
    `${label} must be a non-empty string`
  );
}


function validateManifest(
  manifest,
  filename
) {
  assert(
    manifest &&
    typeof manifest ===
      "object",
    `${filename}: manifest must be an object`
  );

  assertString(
    manifest.exportName,
    `${filename}.exportName`
  );

  const activity =
    manifest.activity;

  assert(
    activity &&
    typeof activity ===
      "object",
    `${filename}.activity is required`
  );

  assertString(
    activity.id,
    `${filename}.activity.id`
  );

  assert(
    Number.isInteger(
      activity.version
    ) &&
    activity.version >
      0,
    `${filename}.activity.version must be a positive integer`
  );

  assertString(
    activity.mechanic,
    `${filename}.activity.mechanic`
  );

  assertString(
    activity.ageBand,
    `${filename}.activity.ageBand`
  );

  assert(
    Array.isArray(
      activity.options
    ) &&
    activity.options.length >=
      2,
    `${filename}.activity.options must contain at least two choices`
  );

  const correctCount =
    activity.options.filter(
      option =>
        option.correct ===
        true
    ).length;

  assert(
    correctCount ===
      1,
    `${filename}: tap-choice activity must have exactly one correct option`
  );

  assert(
    activity.wellbeing &&
    activity.wellbeing.usesCountdownPressure ===
      false &&
    activity.wellbeing.usesLossAversion ===
      false &&
    activity.wellbeing.usesStreakPressure ===
      false &&
    activity.wellbeing.usesInfinitePlay ===
      false &&
    activity.wellbeing.usesBehaviouralAds ===
      false,
    `${filename}: wellbeing guardrails must remain disabled`
  );

  assert(
    activity.provenance &&
    activity.provenance.type ===
      "original" &&
    activity.provenance.creator ===
      "HIBEYA" &&
    activity.provenance.originalityReviewed ===
      true,
    `${filename}: original HIBEYA provenance review is required`
  );

  const catalogue =
    manifest.catalogue;

  assert(
    catalogue &&
    typeof catalogue ===
      "object",
    `${filename}.catalogue is required`
  );

  assertString(
    catalogue.blueprintId,
    `${filename}.catalogue.blueprintId`
  );

  assertString(
    catalogue.implementationKey,
    `${filename}.catalogue.implementationKey`
  );

  assert(
    Array.isArray(
      catalogue.ageBands
    ) &&
    catalogue.ageBands.length >
      0,
    `${filename}.catalogue.ageBands is required`
  );

  assert(
    catalogue.ageBands.includes(
      activity.ageBand
    ),
    `${filename}: primary activity ageBand must be present in catalogue.ageBands`
  );

  const insights =
    manifest.learningInsights;

  assert(
    insights &&
    Array.isArray(
      insights.objectives
    ),
    `${filename}.learningInsights.objectives is required`
  );
}


function listManifests() {
  if (
    !fs.existsSync(
      manifestRoot
    )
  ) {
    fail(
      `Manifest directory not found: ${manifestRoot}`
    );
  }

  return fs
    .readdirSync(
      manifestRoot
    )
    .filter(
      file =>
        file.endsWith(
          ".json"
        )
    )
    .sort();
}


const manifestFiles =
  listManifests();

assert(
  manifestFiles.length >
    0,
  "No activity manifests found"
);


const manifests =
  manifestFiles.map(
    filename => {
      const fullPath =
        path.join(
          manifestRoot,
          filename
        );

      const manifest =
        readJson(
          fullPath
        );

      validateManifest(
        manifest,
        filename
      );

      return {
        filename,
        manifest
      };
    }
  );


const activityIds =
  manifests.map(
    item =>
      item.manifest
        .activity
        .id
  );


assert(
  new Set(
    activityIds
  ).size ===
    activityIds.length,
  "Duplicate activity IDs are not allowed"
);


const exportNames =
  manifests.map(
    item =>
      item.manifest
        .exportName
  );


assert(
  new Set(
    exportNames
  ).size ===
    exportNames.length,
  "Duplicate export names are not allowed"
);


function jsonTs(
  value
) {
  return JSON.stringify(
    value,
    null,
    2
  );
}


function activitySource(
  manifest
) {
  return `import {
  ActivitySchema,
  type ActivityContent
} from "@akal-budi/content-schema";


const activity =
${jsonTs(manifest.activity)}
  satisfies ActivityContent;


export const ${manifest.exportName} =
  ActivitySchema.parse(
    activity
  );
`;
}


function catalogueSource() {
  const rows =
    manifests.map(
      ({ manifest }) => {
        const c =
          manifest.catalogue;

        return `    {
      id:
        ${JSON.stringify(manifest.activity.id)},

      blueprintId:
        ${JSON.stringify(c.blueprintId)},

      version:
        ${manifest.activity.version},

      enabled:
        ${Boolean(c.enabled)},

      ageBands:
        ${jsonTs(c.ageBands).replace(/\n/g, "\n        ")},

      titleMs:
        ${JSON.stringify(c.titleMs)},

      titleEn:
        ${JSON.stringify(c.titleEn)},

      implementationKey:
        ${JSON.stringify(c.implementationKey)}
    }`;
      }
    )
    .join(
      ",\n\n"
    );

  return `import {
  activityBlueprints,
  type AgeBand,
  type ActivityBlueprint
} from "@akal-budi/content-architecture";


export interface PlayableActivity {
  id: string;

  blueprintId: string;

  version: number;

  enabled: boolean;

  ageBands:
    readonly AgeBand[];

  titleMs: string;

  titleEn: string;

  implementationKey:
    string;
}


export interface ResolvedPlayableActivity
  extends PlayableActivity {
  blueprint:
    ActivityBlueprint;
}


export const playableActivities:
  readonly PlayableActivity[] = [

${rows}

  ];


export function getPlayableActivity(
  activityId: string
): ResolvedPlayableActivity | null {

  const activity =
    playableActivities.find(
      item =>
        item.id ===
        activityId
    );


  if (!activity) {
    return null;
  }


  const blueprint =
    activityBlueprints.find(
      item =>
        item.id ===
        activity.blueprintId
    );


  if (!blueprint) {
    return null;
  }


  return {
    ...activity,
    blueprint
  };
}


export function getPlayableActivitiesForAgeBand(
  ageBand: AgeBand
): ResolvedPlayableActivity[] {

  return playableActivities
    .filter(
      activity =>
        activity.enabled &&
        activity
          .ageBands
          .includes(
            ageBand
          )
    )
    .map(
      activity =>
        getPlayableActivity(
          activity.id
        )
    )
    .filter(
      (
        activity
      ): activity is ResolvedPlayableActivity =>
        activity !==
        null
    );
}
`;
}


function contentIndexSource() {
  const activityExports =
    manifests.map(
      ({ manifest }) =>
        `export {
  ${manifest.exportName}
} from "./activities/${manifest.activity.id}";`
    )
    .join(
      "\n\n"
    );

  return `${activityExports}


export {
  getPlayableActivitiesForAgeBand,
  getPlayableActivity,
  playableActivities
} from "./catalogue";


export {
  validatePlayableCatalogue
} from "./validateCatalogue";


export type {
  PlayableActivity,
  ResolvedPlayableActivity
} from "./catalogue";


export type {
  CatalogueIssue
} from "./validateCatalogue";
`;
}


function registrySource() {
  const imports =
    manifests
      .map(
        ({ manifest }) =>
          `  ${manifest.exportName}`
      )
      .join(
        ",\n"
      );

  const union =
    manifests
      .map(
        ({ manifest }) =>
          `typeof ${manifest.exportName}`
      )
      .join(
        " |\n  "
      );

  const implementations =
    manifests
      .map(
        ({ manifest }) =>
          `    {
      activityId:
        ${JSON.stringify(manifest.activity.id)},

      implementationKey:
        ${JSON.stringify(manifest.catalogue.implementationKey)},

      activity:
        ${manifest.exportName}
    }`
      )
      .join(
        ",\n\n"
      );

  return `import {
${imports}
} from "@akal-budi/content-library";


type SupportedActivity =
  ${union};


export interface ActivityImplementation {
  activityId: string;

  implementationKey:
    string;

  activity:
    SupportedActivity;
}


const implementations:
  readonly ActivityImplementation[] = [

${implementations}

  ];


export function getActivityImplementation(
  activityId: string,
  implementationKey: string
): ActivityImplementation | null {

  return (
    implementations.find(
      implementation =>
        implementation
          .activityId ===
          activityId &&
        implementation
          .implementationKey ===
          implementationKey
    ) ??
    null
  );
}


export function hasActivityImplementation(
  activityId: string,
  implementationKey: string
): boolean {

  return implementations.some(
    implementation =>
      implementation
        .activityId ===
        activityId &&
      implementation
        .implementationKey ===
        implementationKey
  );
}
`;
}


function learningMetadataSource() {
  const entries =
    manifests
      .map(
        ({ manifest }) => {
          const insights =
            manifest.learningInsights;

          const malaysia =
            Array.isArray(
              insights.malaysiaElements
            ) &&
            insights.malaysiaElements.length >
              0
              ? `,\n\n      malaysiaElements:\n        ${jsonTs(insights.malaysiaElements).replace(/\n/g, "\n        ")}`
              : "";

          return `    {
      activityId:
        ${JSON.stringify(manifest.activity.id)},

      objectives:
        ${jsonTs(insights.objectives).replace(/\n/g, "\n        ")}${malaysia}
    }`;
        }
      )
      .join(
        ",\n\n"
      );

  return `import type {
  ActivityLearningMetadata
} from "./types";


export const activityLearningMetadata:
  readonly ActivityLearningMetadata[] = [

${entries}

  ];
`;
}


const outputs =
  new Map();


for (
  const {
    manifest
  }
  of manifests
) {
  outputs.set(
    path.join(
      repoRoot,
      "packages",
      "content-library",
      "src",
      "activities",
      `${manifest.activity.id}.ts`
    ),
    activitySource(
      manifest
    )
  );
}


outputs.set(
  path.join(
    repoRoot,
    "packages",
    "content-library",
    "src",
    "catalogue.ts"
  ),
  catalogueSource()
);


outputs.set(
  path.join(
    repoRoot,
    "packages",
    "content-library",
    "src",
    "index.ts"
  ),
  contentIndexSource()
);


outputs.set(
  path.join(
    repoRoot,
    "apps",
    "learner-web",
    "src",
    "features",
    "play",
    "activityRegistry.ts"
  ),
  registrySource()
);


outputs.set(
  path.join(
    repoRoot,
    "packages",
    "learning-insights",
    "src",
    "activityMetadata.ts"
  ),
  learningMetadataSource()
);


const checkOnly =
  process.argv.includes(
    "--check"
  );


let mismatch =
  false;


for (
  const [
    filePath,
    content
  ]
  of outputs
) {
  const normalised =
    content
      .trimEnd() +
    "\n";


  if (checkOnly) {
    const existing =
      fs.existsSync(
        filePath
      )
        ? fs.readFileSync(
            filePath,
            "utf8"
          )
        : null;


    if (
      existing !==
      normalised
    ) {
      mismatch =
        true;

      console.error(
        `OUT OF DATE: ${path.relative(repoRoot, filePath)}`
      );
    }

    continue;
  }


  fs.mkdirSync(
    path.dirname(
      filePath
    ),
    {
      recursive:
        true
    }
  );


  fs.writeFileSync(
    filePath,
    normalised,
    "utf8"
  );


  console.log(
    `GENERATED: ${path.relative(repoRoot, filePath)}`
  );
}


if (
  checkOnly &&
  mismatch
) {
  process.exit(2);
}


if (checkOnly) {
  console.log(
    "CONTENT COMPILER CHECK: PASS"
  );
} else {
  console.log(
    `CONTENT COMPILER: ${manifests.length} manifests compiled`
  );
}
'@

Write-Utf8NoBom `
  -Path (Join-Path $compilerRoot "compile.mjs") `
  -Content $compiler


# ------------------------------------------------------------------
# Create a helper for future activities.
# ------------------------------------------------------------------

Write-Step "Installing new-activity manifest helper"

$newActivity = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const [
  ,
  ,
  activityId
] =
  process.argv;


if (
  !activityId ||
  !/^[a-z0-9-]+$/.test(
    activityId
  )
) {
  console.error(
    "Usage: node tools/content-compiler/new-activity.mjs <activity-id>"
  );

  process.exit(1);
}


const repoRoot =
  process.cwd();

const target =
  path.join(
    repoRoot,
    "content",
    "activity-manifests",
    `${activityId}.json`
  );


if (
  fs.existsSync(
    target
  )
) {
  console.error(
    `Manifest already exists: ${target}`
  );

  process.exit(1);
}


const exportName =
  activityId
    .split("-")
    .map(
      (
        part,
        index
      ) =>
        index ===
          0
          ? part
          : part
              .charAt(0)
              .toUpperCase() +
            part.slice(1)
    )
    .join("")
    .replace(
      /[^a-zA-Z0-9_$]/g,
      ""
    );


const manifest = {
  exportName,

  activity: {
    id:
      activityId,

    version:
      1,

    mechanic:
      "tap-choice",

    ageBand:
      "3-4",

    domains: [
      "logic"
    ],

    skills: [
      "visual-discrimination"
    ],

    difficulty:
      1,

    title: {
      ms:
        "TODO",

      en:
        "TODO"
    },

    instruction: {
      ms:
        "TODO",

      en:
        "TODO"
    },

    options: [
      {
        id:
          "TODO-correct",

        asset:
          "TODO",

        correct:
          true
      },

      {
        id:
          "TODO-other",

        asset:
          "TODO",

        correct:
          false
      }
    ],

    development: {
      objectiveIds: [
        "TODO"
      ],

      rationale: {
        ms:
          "TODO",

        en:
          "TODO"
      },

      interactionMode:
        "independent",

      estimatedMinutes:
        2,

      parentParticipationRecommended:
        false,

      offlineExtension: {
        ms:
          "TODO",

        en:
          "TODO"
      },

      researchRefs: [
        "AB-RESEARCH-EARLY-PLAY-001"
      ]
    },

    wellbeing: {
      sensoryLoad:
        "low",

      rewardIntensity:
        1,

      animationIntensity:
        0,

      audioIntensity:
        0,

      usesCountdownPressure:
        false,

      usesLossAversion:
        false,

      usesStreakPressure:
        false,

      usesInfinitePlay:
        false,

      usesBehaviouralAds:
        false,

      penalisesMistakes:
        false
    },

    malaysia: {
      relevance:
        "supporting",

      elements: [],

      culturalReviewRequired:
        true
    },

    accessibility: {
      reducedMotionSafe:
        true,

      requiresReading:
        false,

      requiresAudio:
        false,

      colourIsLearningTarget:
        false,

      largeTouchTargets:
        true,

      alternativeInstructionAvailable:
        true
    },

    provenance: {
      type:
        "original",

      creator:
        "HIBEYA",

      assetSourceRefs: [],

      originalityReviewed:
        false,

      culturalReviewed:
        false,

      reviewedBy:
        "PENDING",

      reviewedAt:
        new Date(
          0
        ).toISOString()
    },

    metadata: {
      estimatedSeconds:
        120,

      active:
        false
    }
  },

  catalogue: {
    blueprintId:
      "TODO",

    enabled:
      false,

    ageBands: [
      "3-4"
    ],

    titleMs:
      "TODO",

    titleEn:
      "TODO",

    implementationKey:
      "colour-choice-v1"
  },

  learningInsights: {
    objectives: [],
    malaysiaElements: []
  }
};


fs.mkdirSync(
  path.dirname(
    target
  ),
  {
    recursive:
      true
  }
);


fs.writeFileSync(
  target,
  JSON.stringify(
    manifest,
    null,
    2
  ) +
  "\n",
  "utf8"
);


console.log(
  `CREATED: ${path.relative(repoRoot, target)}`
);

console.log(
  "Complete the TODO fields, provenance review and cultural review before enabling the activity."
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $compilerRoot "new-activity.mjs") `
  -Content $newActivity


# ------------------------------------------------------------------
# Compile and validate.
# ------------------------------------------------------------------

Invoke-Native `
  -Name "Compile manifests" `
  -Command "node tools\content-compiler\compile.mjs"

Invoke-Native `
  -Name "Content compiler reproducibility check" `
  -Command "node tools\content-compiler\compile.mjs --check"

Invoke-Native `
  -Name "Typecheck" `
  -Command "pnpm typecheck"

Invoke-Native `
  -Name "Learner web tests" `
  -Command "pnpm --filter learner-web test"

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
  -Name "Supabase migration dry-run" `
  -Command "pnpm supabase db push --dry-run"

Invoke-Native `
  -Name "Git whitespace check" `
  -Command "git diff --check"


if ($Commit) {
  Invoke-Native `
    -Name "Git stage" `
    -Command "git add ."

  Invoke-Native `
    -Name "Git commit" `
    -Command 'git commit -m "feat: add manifest-driven content compiler"'
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 005: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Future activity workflow:" -ForegroundColor White
Write-Host "  node tools\content-compiler\new-activity.mjs <activity-id>" -ForegroundColor Cyan
Write-Host "  edit one manifest" -ForegroundColor Cyan
Write-Host "  node tools\content-compiler\compile.mjs" -ForegroundColor Cyan
Write-Host ""
Write-Host "No registry/catalogue copy-paste is required anymore." -ForegroundColor Green
