param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008k-prerequisite-eligibility-$runId.log"

$compilerPath = Join-Path $root "tools\content-compiler\compile.mjs"
$newActivityPath = Join-Path $root "tools\content-compiler\new-activity.mjs"
$packagePath = Join-Path $root "package.json"
$skillGraphPath = Join-Path $root "content\curriculum\skill-graph.json"
$manifestDir = Join-Path $root "content\activity-manifests"
$eligibilityPath = Join-Path $root "packages\content-library\src\eligibility.ts"
$eligibilityTestPath = Join-Path $root "packages\content-library\src\__tests__\eligibility.test.ts"
$selectorPath = Join-Path $root "apps\learner-web\src\features\play\selectLearnerActivity.ts"
$selectorTestPath = Join-Path $root "apps\learner-web\src\features\play\selectLearnerActivity.test.ts"
$validatorPath = Join-Path $root "tools\content-compiler\validate-eligibility.mjs"

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
    $out = Join-Path $logs "phase008k-$stamp-out.log"
    $err = Join-Path $logs "phase008k-$stamp-err.log"

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
        $diag = Join-Path $logs "FAILED-phase008k-$stamp-$($Name.Replace(' ','-')).log"
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
    Write-Host "PHASE 008K: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    Write-Host "Do not make manual source edits unless explicitly requested after log review." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008K" -ForegroundColor Cyan
Write-Host "Prerequisite-Aware Activity Eligibility" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# 1. Verify exact preflight contracts before writing anything.
# ------------------------------------------------------------------

foreach ($required in @(
    $compilerPath,
    $newActivityPath,
    $packagePath,
    $skillGraphPath,
    $manifestDir,
    $selectorPath
)) {
    if (-not (Test-Path $required)) {
        throw "Required Phase 008K dependency missing: $required"
    }
}

$compiler = Get-Content $compilerPath -Raw
$helper = Get-Content $newActivityPath -Raw
$selector = Get-Content $selectorPath -Raw
$skillGraph = Get-Content $skillGraphPath -Raw | ConvertFrom-Json

foreach ($token in @(
    "function catalogueSource()",
    "manifest.catalogue",
    "sequence: number;",
    "getPlayableActivitiesForAgeBand",
    "function contentIndexSource()",
    "const manifestRoot ="
)) {
    if ($compiler -notmatch [Regex]::Escape($token)) {
        throw "Content compiler contract drifted. Missing token: $token"
    }
}

foreach ($token in @(
    "getPlayableActivitiesForAgeBand",
    "resolveNextLearnerActivity",
    "completedActivityIds"
)) {
    if ($selector -notmatch [Regex]::Escape($token)) {
        throw "Learner selector contract drifted. Missing token: $token"
    }
}

if ($compiler -match "requiredPrerequisiteSkillIds") {
    throw "Compiler already appears prerequisite-aware. Refusing duplicate Phase 008K migration."
}

if ($null -eq $skillGraph.skills -or $null -eq $skillGraph.prerequisites) {
    throw "Canonical skill graph must contain skills[] and prerequisites[]."
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

    if ($null -eq $manifest.skillMappings) {
        throw "$($file.Name): skillMappings[] missing."
    }

    if ($null -eq $manifest.catalogue) {
        throw "$($file.Name): catalogue object missing."
    }

    if ($manifest.catalogue.PSObject.Properties.Name -notcontains "sequence") {
        throw "$($file.Name): catalogue.sequence missing; Phase 008J is not intact."
    }
}

Write-Host "PASS: compiler, selector, skill graph and manifest contracts verified" -ForegroundColor Green
Write-Host "PASS: Phase 008J sequencing contract is intact" -ForegroundColor Green

# ------------------------------------------------------------------
# 2. Backups.
# ------------------------------------------------------------------

foreach ($path in @(
    $compilerPath,
    $newActivityPath,
    $packagePath,
    $selectorPath,
    $selectorTestPath,
    $eligibilityPath,
    $eligibilityTestPath,
    $validatorPath
)) {
    Backup $path
}

# ------------------------------------------------------------------
# 3. Pure prerequisite eligibility engine.
#    Content-library owns the rule; learner-web remains content agnostic.
# ------------------------------------------------------------------

WriteText $eligibilityPath @'
import type {
  AgeBand
} from "@akal-budi/content-architecture";

import {
  getPlayableActivitiesForAgeBand,
  playableActivities,
  type ResolvedPlayableActivity
} from "./catalogue";


export interface LearnerEligibilityInput {
  ageBand:
    AgeBand;

  completedActivityIds:
    readonly string[];
}


export function deriveCompletedSkillIds(
  completedActivityIds:
    readonly string[]
):
  Set<string> {
  const completed =
    new Set(
      completedActivityIds
    );

  const skills =
    new Set<string>();

  for (
    const activity
    of playableActivities
  ) {
    if (
      !completed.has(
        activity.id
      )
    ) {
      continue;
    }

    for (
      const skillId
      of activity.skillIds
    ) {
      skills.add(
        skillId
      );
    }
  }

  return skills;
}


export function isActivityPrerequisiteEligible(
  activity:
    ResolvedPlayableActivity,
  completedSkillIds:
    ReadonlySet<string>
):
  boolean {
  return activity
    .requiredPrerequisiteSkillIds
    .every(
      skillId =>
        completedSkillIds.has(
          skillId
        )
    );
}


export function getEligibleActivitiesForLearner({
  ageBand,
  completedActivityIds
}: LearnerEligibilityInput):
  ResolvedPlayableActivity[] {
  const completedSkillIds =
    deriveCompletedSkillIds(
      completedActivityIds
    );

  return getPlayableActivitiesForAgeBand(
    ageBand
  ).filter(
    activity =>
      isActivityPrerequisiteEligible(
        activity,
        completedSkillIds
      )
  );
}
'@

WriteText $eligibilityTestPath @'
import {
  describe,
  expect,
  it
} from "vitest";

import type {
  ResolvedPlayableActivity
} from "../catalogue";

import {
  deriveCompletedSkillIds,
  isActivityPrerequisiteEligible
} from "../eligibility";


function activity(
  id: string,
  requiredPrerequisiteSkillIds:
    readonly string[] = []
):
  ResolvedPlayableActivity {
  return {
    id,
    requiredPrerequisiteSkillIds
  } as ResolvedPlayableActivity;
}


describe(
  "prerequisite eligibility",
  () => {
    it(
      "allows an activity with no required prerequisites",
      () => {
        expect(
          isActivityPrerequisiteEligible(
            activity("a"),
            new Set()
          )
        ).toBe(
          true
        );
      }
    );


    it(
      "blocks an activity when a required prerequisite is incomplete",
      () => {
        expect(
          isActivityPrerequisiteEligible(
            activity(
              "b",
              ["skill-a"]
            ),
            new Set()
          )
        ).toBe(
          false
        );
      }
    );


    it(
      "allows an activity when all required prerequisites are complete",
      () => {
        expect(
          isActivityPrerequisiteEligible(
            activity(
              "c",
              [
                "skill-a",
                "skill-b"
              ]
            ),
            new Set([
              "skill-a",
              "skill-b"
            ])
          )
        ).toBe(
          true
        );
      }
    );


    it(
      "requires every required prerequisite rather than any one prerequisite",
      () => {
        expect(
          isActivityPrerequisiteEligible(
            activity(
              "c",
              [
                "skill-a",
                "skill-b"
              ]
            ),
            new Set([
              "skill-a"
            ])
          )
        ).toBe(
          false
        );
      }
    );


    it(
      "ignores unknown completed activity ids when deriving skills",
      () => {
        expect(
          Array.from(
            deriveCompletedSkillIds([
              "legacy-unknown-activity"
            ])
          )
        ).toEqual(
          []
        );
      }
    );
  }
);
'@

# ------------------------------------------------------------------
# 4. Patch compiler and helper atomically.
# ------------------------------------------------------------------

$editor = Join-Path $env:TEMP "hibeya-phase008k-editor-$runId.cjs"

WriteText $editor @'
const fs = require("fs");

const [
  compilerPath,
  helperPath,
  packagePath
] = process.argv.slice(2);

function read(file) {
  return fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
}

function requireCondition(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

let compiler = read(compilerPath);
let helper = read(helperPath);
const pkg = JSON.parse(read(packagePath));

// ------------------------------------------------------------
// Compiler: load canonical skill graph.
// ------------------------------------------------------------

const manifestRootAnchor =
`const manifestRoot =
  path.join(
    repoRoot,
    "content",
    "activity-manifests"
  );
`;

requireCondition(
  compiler.includes(manifestRootAnchor),
  "Compiler manifestRoot anchor not found."
);

compiler = compiler.replace(
  manifestRootAnchor,
`${manifestRootAnchor}

const skillGraphPath =
  path.join(
    repoRoot,
    "content",
    "curriculum",
    "skill-graph.json"
  );


const skillGraph =
  readJson(
    skillGraphPath
  );


const requiredPrerequisitesBySkill =
  new Map();


for (
  const edge
  of skillGraph.prerequisites ??
    []
) {
  if (
    edge.strength !==
      "required"
  ) {
    continue;
  }

  const existing =
    requiredPrerequisitesBySkill.get(
      edge.skillId
    ) ??
    [];

  existing.push(
    edge.prerequisiteSkillId
  );

  requiredPrerequisitesBySkill.set(
    edge.skillId,
    existing
  );
}
`
);

// readJson is function-declared, so hoisting makes this safe even though
// skillGraph is initialised before the textual readJson declaration.

// ------------------------------------------------------------
// Compiler validation: skillMappings shape.
// ------------------------------------------------------------

const insightsAnchor =
`  const insights =
    manifest.learningInsights;
`;

requireCondition(
  compiler.includes(insightsAnchor),
  "Compiler learningInsights validation anchor not found."
);

compiler = compiler.replace(
  insightsAnchor,
`  assert(
    Array.isArray(
      manifest.skillMappings
    ) &&
    manifest.skillMappings.length >
      0,
    \`${"${filename}"}.skillMappings must contain at least one skill mapping\`
  );

  assert(
    manifest.skillMappings.some(
      mapping =>
        mapping.role ===
          "primary"
    ),
    \`${"${filename}"}.skillMappings must contain at least one primary skill\`
  );

  const insights =
    manifest.learningInsights;
`
);

// ------------------------------------------------------------
// Compiler catalogue row: skill and prerequisite metadata.
// ------------------------------------------------------------

const rowAnchor =
`      sequence:
        \${c.sequence},

      ageBands:`;

requireCondition(
  compiler.includes(rowAnchor),
  "Compiler catalogue row sequence anchor not found."
);

compiler = compiler.replace(
  rowAnchor,
`      sequence:
        \${c.sequence},

      skillIds:
        \${jsonTs(
          Array.from(
            new Set(
              manifest.skillMappings.map(
                mapping =>
                  mapping.skillId
              )
            )
          )
        ).replace(/\\n/g, "\\n        ")},

      primarySkillIds:
        \${jsonTs(
          Array.from(
            new Set(
              manifest.skillMappings
                .filter(
                  mapping =>
                    mapping.role ===
                      "primary"
                )
                .map(
                  mapping =>
                    mapping.skillId
                )
            )
          )
        ).replace(/\\n/g, "\\n        ")},

      requiredPrerequisiteSkillIds:
        \${jsonTs(
          Array.from(
            new Set(
              manifest.skillMappings
                .filter(
                  mapping =>
                    mapping.role ===
                      "primary"
                )
                .flatMap(
                  mapping =>
                    requiredPrerequisitesBySkill.get(
                      mapping.skillId
                    ) ??
                    []
                )
            )
          )
        ).replace(/\\n/g, "\\n        ")},

      ageBands:`
);

// ------------------------------------------------------------
// Compiler PlayableActivity interface.
// ------------------------------------------------------------

const interfaceAnchor =
`  sequence: number;

  ageBands:`;

requireCondition(
  compiler.includes(interfaceAnchor),
  "Compiler PlayableActivity sequence interface anchor not found."
);

compiler = compiler.replace(
  interfaceAnchor,
`  sequence: number;

  skillIds:
    readonly string[];

  primarySkillIds:
    readonly string[];

  requiredPrerequisiteSkillIds:
    readonly string[];

  ageBands:`
);

// ------------------------------------------------------------
// Compiler generated index: export eligibility API.
// ------------------------------------------------------------

const indexAnchor =
`export {
  validatePlayableCatalogue
} from "./validateCatalogue";
`;

requireCondition(
  compiler.includes(indexAnchor),
  "Compiler content index validation export anchor not found."
);

compiler = compiler.replace(
  indexAnchor,
`${indexAnchor}

export {
  deriveCompletedSkillIds,
  getEligibleActivitiesForLearner,
  isActivityPrerequisiteEligible
} from "./eligibility";


export type {
  LearnerEligibilityInput
} from "./eligibility";
`
);

// ------------------------------------------------------------
// New-activity helper: ensure curriculum metadata is created.
// Existing helper currently creates activity.skills but not skillMappings.
// ------------------------------------------------------------

const insightsObject =
`  learningInsights: {
    objectives: [],
    malaysiaElements: []
  }
};`;

requireCondition(
  helper.includes(insightsObject),
  "new-activity learningInsights tail anchor not found."
);

helper = helper.replace(
  insightsObject,
`  learningInsights: {
    objectives: [],
    malaysiaElements: []
  },

  curriculumMappings:
    [],

  skillMappings: [
    {
      skillId:
        "visual-discrimination",

      role:
        "primary",

      weight:
        1
    }
  ]
};`
);

// ------------------------------------------------------------
// Root command.
// ------------------------------------------------------------

pkg.scripts ??= {};
pkg.scripts["content:eligibility:validate"] =
  "node tools/content-compiler/validate-eligibility.mjs";

// ------------------------------------------------------------
// Postconditions before write.
// ------------------------------------------------------------

for (const token of [
  "requiredPrerequisitesBySkill",
  "requiredPrerequisiteSkillIds:",
  "primarySkillIds:",
  "skillIds:",
  'from "./eligibility"'
]) {
  requireCondition(
    compiler.includes(token),
    `Compiler postcondition failed: ${token}`
  );
}

requireCondition(
  helper.includes("skillMappings: ["),
  "new-activity skillMappings postcondition failed."
);

fs.writeFileSync(
  compilerPath,
  compiler,
  "utf8"
);

fs.writeFileSync(
  helperPath,
  helper,
  "utf8"
);

fs.writeFileSync(
  packagePath,
  JSON.stringify(
    pkg,
    null,
    2
  ) + "\n",
  "utf8"
);

console.log("PASS: content compiler emits prerequisite eligibility metadata");
console.log("PASS: new-activity helper now creates curriculum-ready skill mappings");
console.log("PASS: eligibility validation command registered");
'@

& node `
    $editor `
    $compilerPath `
    $newActivityPath `
    $packagePath

if ($LASTEXITCODE -ne 0) {
    throw "Phase 008K compiler/helper transformation failed."
}

Remove-Item $editor -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------------
# 5. Durable eligibility validator.
# ------------------------------------------------------------------

WriteText $validatorPath @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const root =
  process.cwd();

const graphPath =
  path.join(
    root,
    "content",
    "curriculum",
    "skill-graph.json"
  );

const manifestDir =
  path.join(
    root,
    "content",
    "activity-manifests"
  );

const failures =
  [];


function fail(
  message
) {
  failures.push(
    message
  );
}


function readJson(
  file
) {
  return JSON.parse(
    fs.readFileSync(
      file,
      "utf8"
    )
  );
}


if (
  !fs.existsSync(
    graphPath
  )
) {
  fail(
    "Canonical skill graph is missing."
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


const graph =
  fs.existsSync(
    graphPath
  )
    ? readJson(
        graphPath
      )
    : {
        skills: [],
        prerequisites: []
      };


const skills =
  Array.isArray(
    graph.skills
  )
    ? graph.skills
    : [];

const prerequisites =
  Array.isArray(
    graph.prerequisites
  )
    ? graph.prerequisites
    : [];


const skillIds =
  new Set(
    skills.map(
      skill =>
        skill.id
    )
  );


for (
  const edge
  of prerequisites
) {
  if (
    ![
      "required",
      "recommended"
    ].includes(
      edge.strength
    )
  ) {
    fail(
      `Invalid prerequisite strength for ${edge.skillId}: ${edge.strength}`
    );
  }

  if (
    !skillIds.has(
      edge.skillId
    )
  ) {
    fail(
      `Unknown prerequisite target skill: ${edge.skillId}`
    );
  }

  if (
    !skillIds.has(
      edge.prerequisiteSkillId
    )
  ) {
    fail(
      `Unknown prerequisite source skill: ${edge.prerequisiteSkillId}`
    );
  }
}


const manifests =
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
          file => ({
            file,
            manifest:
              readJson(
                path.join(
                  manifestDir,
                  file
                )
              )
          })
        )
    : [];


for (
  const {
    file,
    manifest
  }
  of manifests
) {
  const mappings =
    Array.isArray(
      manifest.skillMappings
    )
      ? manifest.skillMappings
      : [];

  if (
    mappings.length ===
      0
  ) {
    fail(
      `${file}: skillMappings[] must not be empty`
    );

    continue;
  }

  const mappedIds =
    mappings.map(
      mapping =>
        mapping.skillId
    );

  if (
    new Set(
      mappedIds
    ).size !==
      mappedIds.length
  ) {
    fail(
      `${file}: duplicate skill mappings are not allowed`
    );
  }

  if (
    !mappings.some(
      mapping =>
        mapping.role ===
          "primary"
    )
  ) {
    fail(
      `${file}: at least one primary skill mapping is required`
    );
  }

  const activitySkills =
    Array.isArray(
      manifest.activity?.skills
    )
      ? new Set(
          manifest.activity.skills
        )
      : new Set();

  for (
    const mapping
    of mappings
  ) {
    if (
      !skillIds.has(
        mapping.skillId
      )
    ) {
      fail(
        `${file}: unknown mapped skill ${mapping.skillId}`
      );
    }

    if (
      !activitySkills.has(
        mapping.skillId
      )
    ) {
      fail(
        `${file}: skillMappings contains ${mapping.skillId} but activity.skills does not`
      );
    }
  }
}


// Reachability guard for REQUIRED prerequisite edges.
// An enabled activity teaching a primary target skill must have a possible
// earlier enabled activity in at least one shared age band that teaches each
// required prerequisite skill.
for (
  const {
    file,
    manifest
  }
  of manifests
) {
  if (
    manifest.catalogue?.enabled !==
      true
  ) {
    continue;
  }

  const primarySkills =
    (manifest.skillMappings ??
      [])
      .filter(
        mapping =>
          mapping.role ===
            "primary"
      )
      .map(
        mapping =>
          mapping.skillId
      );

  const required =
    prerequisites.filter(
      edge =>
        edge.strength ===
          "required" &&
        primarySkills.includes(
          edge.skillId
        )
    );

  for (
    const edge
    of required
  ) {
    const targetBands =
      manifest.catalogue?.ageBands ??
      [];

    const targetSequence =
      manifest.catalogue?.sequence;

    const sourceExists =
      manifests.some(
        candidate => {
          if (
            candidate.manifest.catalogue?.enabled !==
              true
          ) {
            return false;
          }

          if (
            !Number.isInteger(
              candidate.manifest.catalogue?.sequence
            ) ||
            candidate.manifest.catalogue.sequence >=
              targetSequence
          ) {
            return false;
          }

          const sharedBand =
            (
              candidate.manifest.catalogue?.ageBands ??
              []
            ).some(
              ageBand =>
                targetBands.includes(
                  ageBand
                )
            );

          if (!sharedBand) {
            return false;
          }

          return (
            candidate.manifest.skillMappings ??
            []
          ).some(
            mapping =>
              mapping.skillId ===
                edge.prerequisiteSkillId
          );
        }
      );

    if (!sourceExists) {
      fail(
        `${file}: required prerequisite ${edge.prerequisiteSkillId} for ${edge.skillId} has no earlier enabled teaching activity in a shared age band`
      );
    }
  }
}


if (
  failures.length >
    0
) {
  console.error(
    "CONTENT ELIGIBILITY VALIDATION: FAILED"
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
  `CONTENT ELIGIBILITY VALIDATION: PASS (${manifests.length} manifests, ${prerequisites.length} prerequisite edges)`
);
'@

Write-Host "PASS: durable prerequisite eligibility validator installed" -ForegroundColor Green

# ------------------------------------------------------------------
# 6. Learner selector now asks content-library for eligible catalogue.
# ------------------------------------------------------------------

WriteText $selectorPath @'
import {
  getEligibleActivitiesForLearner,
  type ResolvedPlayableActivity
} from "@akal-budi/content-library";

import type {
  LearnerAgeBand
} from "../../services/deviceActivationService";

import {
  resolveNextLearnerActivity
} from "../../journey/nextLearnerActivity.service";


export interface LearnerActivitySelectionInput {
  ageBand:
    LearnerAgeBand;

  lastCompletedActivityId:
    string | null;

  completedActivityIds?:
    readonly string[];
}


export function selectLearnerActivity({
  ageBand,
  lastCompletedActivityId,
  completedActivityIds = []
}: LearnerActivitySelectionInput):
  ResolvedPlayableActivity |
  null {
  return resolveNextLearnerActivity({
    activities:
      getEligibleActivitiesForLearner({
        ageBand,
        completedActivityIds
      }),

    completedActivityIds,

    lastCompletedActivityId
  });
}
'@

# Selector regression remains catalogue-driven and now compares against eligibility API.
WriteText $selectorTestPath @'
import {
  describe,
  expect,
  it
} from "vitest";

import {
  getEligibleActivitiesForLearner,
  playableActivities
} from "@akal-budi/content-library";

import type {
  LearnerAgeBand
} from "../../services/deviceActivationService";

import {
  selectLearnerActivity
} from "./selectLearnerActivity";


function getSupportedLearnerAgeBand():
  LearnerAgeBand {
  const candidate =
    playableActivities
      .flatMap(
        activity =>
          activity.ageBands
      )
      .find(
        (
          ageBand
        ): ageBand is LearnerAgeBand =>
          ageBand ===
            "2-3" ||
          ageBand ===
            "3-4" ||
          ageBand ===
            "4-5" ||
          ageBand ===
            "5-6"
      );

  if (!candidate) {
    throw new Error(
      "No playable learner age band is available in the current catalogue."
    );
  }

  return candidate;
}


describe(
  "selectLearnerActivity",
  () => {
    it(
      "follows prerequisite-eligible catalogue order",
      () => {
        const ageBand =
          getSupportedLearnerAgeBand();

        const eligible =
          getEligibleActivitiesForLearner({
            ageBand,
            completedActivityIds:
              []
          });

        const selected =
          selectLearnerActivity({
            ageBand,

            lastCompletedActivityId:
              null,

            completedActivityIds:
              []
          });

        expect(
          selected?.id ??
          null
        ).toBe(
          eligible[0]?.id ??
          null
        );
      }
    );


    it(
      "uses completed activities when resolving eligibility and progression",
      () => {
        const ageBand =
          getSupportedLearnerAgeBand();

        const initial =
          getEligibleActivitiesForLearner({
            ageBand,
            completedActivityIds:
              []
          });

        const first =
          initial[0];

        if (!first) {
          expect(
            selectLearnerActivity({
              ageBand,

              lastCompletedActivityId:
                null,

              completedActivityIds:
                []
            })
          ).toBeNull();

          return;
        }

        const selected =
          selectLearnerActivity({
            ageBand,

            lastCompletedActivityId:
              first.id,

            completedActivityIds:
              [first.id]
          });

        const eligibleAfter =
          getEligibleActivitiesForLearner({
            ageBand,

            completedActivityIds:
              [first.id]
          });

        const firstUncompleted =
          eligibleAfter.find(
            activity =>
              activity.id !==
                first.id
          );

        if (
          firstUncompleted
        ) {
          expect(
            selected?.id
          ).toBe(
            firstUncompleted.id
          );
        }
      }
    );
  }
);
'@

# ------------------------------------------------------------------
# 7. Focused validation first.
# ------------------------------------------------------------------

Run `
    "Curriculum graph validation" `
    "pnpm curriculum:validate"

Run `
    "Content prerequisite eligibility validation" `
    "pnpm content:eligibility:validate"

Run `
    "Compile prerequisite-aware content catalogue" `
    "node tools/content-compiler/compile.mjs"

Run `
    "Content compiler reproducibility" `
    "pnpm content:check"

$cataloguePath = Join-Path $root "packages\content-library\src\catalogue.ts"
$indexPath = Join-Path $root "packages\content-library\src\index.ts"

foreach ($required in @(
    $cataloguePath,
    $indexPath
)) {
    if (-not (Test-Path $required)) {
        throw "Generated content-library output missing: $required"
    }
}

$catalogue = Get-Content $cataloguePath -Raw
$contentIndex = Get-Content $indexPath -Raw

foreach ($token in @(
    "skillIds:",
    "primarySkillIds:",
    "requiredPrerequisiteSkillIds:"
)) {
    if ($catalogue -notmatch [Regex]::Escape($token)) {
        throw "Generated catalogue prerequisite metadata missing: $token"
    }
}

if ($contentIndex -notmatch "getEligibleActivitiesForLearner") {
    throw "Generated content-library index does not export eligibility API."
}

Write-Host "PASS: generated catalogue carries prerequisite eligibility metadata" -ForegroundColor Green
Write-Host "PASS: content-library exports reusable eligibility API" -ForegroundColor Green

Run `
    "Eligibility unit tests" `
    "pnpm --filter @akal-budi/content-library exec vitest run src/__tests__/eligibility.test.ts"

Run `
    "Selector unit tests" `
    "pnpm --filter learner-web exec vitest run src/features/play/selectLearnerActivity.test.ts"

Run `
    "Content library typecheck" `
    "pnpm --filter @akal-budi/content-library typecheck"

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
    "Production build" `
    "pnpm build"

# Rebuild Storybook after monorepo concurrency before browser QA.
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
    "Content sequencing validation" `
    "pnpm content:sequence:validate"

Run `
    "Content eligibility validation final" `
    "pnpm content:eligibility:validate"

Run `
    "Curriculum validation final" `
    "pnpm curriculum:validate"

Run `
    "Git whitespace check" `
    "git diff --check"

if ($Commit) {
    Run `
        "Stage Phase 008K" `
        "git add tools/content-compiler packages/content-library/src apps/learner-web/src/features/play package.json"

    Run `
        "Commit Phase 008K" `
        'git commit -m "feat: add prerequisite-aware activity eligibility"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008K: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Required skill prerequisites now gate learner activity eligibility." -ForegroundColor Cyan
Write-Host "Recommended prerequisites remain advisory and do not block activities." -ForegroundColor Cyan
Write-Host "Learner application code remains content-agnostic." -ForegroundColor Cyan
Write-Host "No persistence/schema migration was required." -ForegroundColor Cyan
Write-Host "No manual intervention is required." -ForegroundColor Cyan
