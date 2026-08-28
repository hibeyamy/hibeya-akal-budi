Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008r1-governed-coverage-$stamp.log"

$newActivity = Join-Path $root "tools\content-compiler\new-activity.mjs"
$coverageValidator = Join-Path $root "tools\content-compiler\validate-coverage.mjs"
$coveragePolicy = Join-Path $root "content\curriculum\coverage-policy.json"
$packageJson = Join-Path $root "package.json"

function Log([string]$Text="") {
    Add-Content -Path $log -Value $Text -Encoding UTF8
}

function Backup([string]$Path) {
    if (-not (Test-Path $Path)) { return }
    $relative = $Path.Substring($root.Length).TrimStart("\")
    $safe = $relative -replace '[\\/:*?"<>|]', '_'
    Copy-Item $Path (Join-Path $backups "$stamp-$safe") -Force
}

function WriteUtf8([string]$Path,[string]$Content) {
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

function Native([string]$Name,[string]$Command) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Write-Host $Command
    Log ""
    Log "==> $Name"
    Log $Command

    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & "$env:ComSpec" /d /c $Command 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $old
    }

    foreach ($item in $output) {
        $text = if ($item -is [System.Management.Automation.ErrorRecord]) {
            $item.Exception.Message
        } else {
            [string]$item
        }
        Write-Host $text
        Log $text
    }

    if ($code -ne 0) {
        throw "$Name failed with exit code $code"
    }

    Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
    Log ""
    Log "PHASE 008R1: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    Write-Host ""
    Write-Host "PHASE 008R1: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    Write-Host "No manual source edit is required until this log is reviewed." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R1" -ForegroundColor Cyan
Write-Host "Governed Curriculum Coverage Foundation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

foreach ($required in @($newActivity,$packageJson,(Join-Path $root "content\curriculum\skill-graph.json"))) {
    if (-not (Test-Path $required)) {
        throw "Required repository contract missing: $required"
    }
}

$author = Get-Content $newActivity -Raw
foreach ($token in @(
    'Usage: node tools/content-compiler/new-activity.mjs <activity-id>',
    'originalityReviewed:',
    'false',
    'catalogue: {',
    'enabled:',
    'skillMappings: [',
    '"visual-discrimination"'
)) {
    if ($author -notmatch [Regex]::Escape($token)) {
        throw "Authoring contract drifted. Missing token: $token"
    }
}

Write-Host "PASS: exact Phase 008R1 authoring contract verified" -ForegroundColor Green
Write-Host "PASS: existing scaffold already creates disabled/unreviewed drafts" -ForegroundColor Green

Backup $newActivity
Backup $packageJson
Backup $coverageValidator
Backup $coveragePolicy

# ------------------------------------------------------------------
# 1. Add parameterised, non-interactive authoring while preserving
#    the existing one-argument command and safe draft defaults.
# ------------------------------------------------------------------

$oldArgs = @'
const [
  ,
  ,
  activityId
] =
  process.argv;
'@

$newArgs = @'
const rawArgs =
  process.argv.slice(2);

const activityId =
  rawArgs[0];

const optionArgs =
  rawArgs.slice(1);

const options = {};

for (
  let index = 0;
  index < optionArgs.length;
  index += 1
) {
  const token =
    optionArgs[index];

  if (
    !token.startsWith("--")
  ) {
    console.error(
      `Unexpected argument: ${token}`
    );

    process.exit(1);
  }

  const key =
    token.slice(2);

  const value =
    optionArgs[index + 1];

  if (
    !value ||
    value.startsWith("--")
  ) {
    console.error(
      `Missing value for --${key}`
    );

    process.exit(1);
  }

  if (
    Object.prototype.hasOwnProperty.call(
      options,
      key
    )
  ) {
    console.error(
      `Duplicate option: --${key}`
    );

    process.exit(1);
  }

  options[key] =
    value;

  index += 1;
}

const allowedOptions =
  new Set([
    "age-band",
    "difficulty",
    "primary-skill",
    "sequence"
  ]);

for (
  const key of
    Object.keys(options)
) {
  if (
    !allowedOptions.has(
      key
    )
  ) {
    console.error(
      `Unknown option: --${key}`
    );

    process.exit(1);
  }
}

const ageBand =
  options["age-band"] ??
    "3-4";

if (
  ![
    "2-3",
    "3-4",
    "4-5",
    "5-6"
  ].includes(
    ageBand
  )
) {
  console.error(
    `Invalid age band: ${ageBand}`
  );

  process.exit(1);
}

const difficulty =
  options.difficulty ===
    undefined
    ? 1
    : Number(
        options.difficulty
      );

if (
  !Number.isInteger(
    difficulty
  ) ||
  difficulty < 1 ||
  difficulty > 5
) {
  console.error(
    "Difficulty must be an integer from 1 to 5."
  );

  process.exit(1);
}

const primarySkill =
  options["primary-skill"] ??
    "visual-discrimination";

if (
  !/^[a-z0-9-]+$/.test(
    primarySkill
  )
) {
  console.error(
    `Invalid primary skill ID: ${primarySkill}`
  );

  process.exit(1);
}

const explicitSequence =
  options.sequence ===
    undefined
    ? null
    : Number(
        options.sequence
      );

if (
  explicitSequence !== null &&
  (
    !Number.isInteger(
      explicitSequence
    ) ||
    explicitSequence < 1
  )
) {
  console.error(
    "Sequence must be a positive integer."
  );

  process.exit(1);
}
'@

if (-not $author.Contains($oldArgs)) {
    throw "new-activity argument anchor not found."
}
$author = $author.Replace($oldArgs,$newArgs)

$oldUsage = '"Usage: node tools/content-compiler/new-activity.mjs <activity-id>"'
$newUsage = '"Usage: node tools/content-compiler/new-activity.mjs <activity-id> [--age-band 2-3|3-4|4-5|5-6] [--difficulty 1-5] [--primary-skill <skill-id>] [--sequence <positive-integer>]"'
$author = $author.Replace($oldUsage,$newUsage)

$author = $author.Replace(
@'
    ageBand:
      "3-4",
'@,
@'
    ageBand,
'@
)

$author = $author.Replace(
@'
    skills: [
      "visual-discrimination"
    ],

    difficulty:
      1,
'@,
@'
    skills: [
      primarySkill
    ],

    difficulty,
'@
)

$author = $author.Replace(
@'
    sequence:
      nextSequence,

    ageBands: [
      "3-4"
    ],
'@,
@'
    sequence:
      explicitSequence ??
        nextSequence,

    ageBands: [
      ageBand
    ],
'@
)

$author = $author.Replace(
@'
      skillId:
        "visual-discrimination",
'@,
@'
      skillId:
        primarySkill,
'@
)

WriteUtf8 $newActivity $author

# ------------------------------------------------------------------
# 2. Configuration-driven coverage policy. This is governance only:
#    it does not alter learner runtime and does not enable content.
# ------------------------------------------------------------------

$policy = @'
{
  "version": 1,
  "activeSkillPolicy": {
    "minimumEnabledPrimaryActivities": 1,
    "targetEnabledPrimaryActivities": 3
  },
  "difficultyReadiness": {
    "minimumDistinctDifficultiesPerContext": 2
  },
  "notes": [
    "Minimum is a release coverage gate, not an instruction to auto-enable drafts.",
    "Target depth supports mastery, remediation, diversity and future difficulty adaptation.",
    "Curriculum claims require separate source and reviewer evidence."
  ]
}
'@
WriteUtf8 $coveragePolicy $policy

# ------------------------------------------------------------------
# 3. Generic coverage validator. No current skill IDs are hard-coded.
# ------------------------------------------------------------------

$validator = @'
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

const policyPath =
  path.join(
    root,
    "content",
    "curriculum",
    "coverage-policy.json"
  );

const manifestDirectory =
  path.join(
    root,
    "content",
    "activity-manifests"
  );

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

const graph =
  readJson(
    graphPath
  );

const policy =
  readJson(
    policyPath
  );

const minimum =
  policy
    .activeSkillPolicy
    .minimumEnabledPrimaryActivities;

const target =
  policy
    .activeSkillPolicy
    .targetEnabledPrimaryActivities;

if (
  !Number.isInteger(
    minimum
  ) ||
  minimum < 0 ||
  !Number.isInteger(
    target
  ) ||
  target < minimum
) {
  throw new Error(
    "Invalid curriculum coverage policy."
  );
}

const activeSkills =
  new Map(
    graph.skills
      .filter(
        skill =>
          skill.active
      )
      .map(
        skill => [
          skill.id,
          skill
        ]
      )
  );

const manifests =
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
          file => ({
            file,
            manifest:
              readJson(
                path.join(
                  manifestDirectory,
                  file
                )
              )
          })
        )
    : [];

const coverage =
  new Map(
    [...activeSkills.keys()]
      .map(
        skillId => [
          skillId,
          {
            enabledPrimary:
              [],
            draftPrimary:
              []
          }
        ]
      )
  );

const errors = [];

for (
  const {
    file,
    manifest
  } of manifests
) {
  const activityId =
    manifest.activity?.id ??
      file;

  const enabled =
    manifest.catalogue?.enabled ===
      true;

  const mappings =
    Array.isArray(
      manifest.skillMappings
    )
      ? manifest.skillMappings
      : [];

  for (
    const mapping of mappings
  ) {
    if (
      mapping.role !==
        "primary"
    ) {
      continue;
    }

    if (
      !activeSkills.has(
        mapping.skillId
      )
    ) {
      errors.push(
        `${activityId}: primary skill is unknown or inactive: ${mapping.skillId}`
      );

      continue;
    }

    const entry =
      coverage.get(
        mapping.skillId
      );

    if (enabled) {
      entry.enabledPrimary.push(
        activityId
      );
    }
    else {
      entry.draftPrimary.push(
        activityId
      );
    }
  }
}

for (
  const [
    skillId,
    entry
  ] of coverage
) {
  const count =
    entry.enabledPrimary.length;

  const state =
    count < minimum
      ? "FAIL"
      : count < target
        ? "DEPTH-GAP"
        : "TARGET";

  console.log(
    [
      state,
      skillId,
      `enabled-primary=${count}`,
      `draft-primary=${entry.draftPrimary.length}`,
      `minimum=${minimum}`,
      `target=${target}`
    ].join(
      " | "
    )
  );

  if (
    count < minimum
  ) {
    errors.push(
      `${skillId}: ${count} enabled primary activities; minimum is ${minimum}`
    );
  }
}

if (
  errors.length > 0
) {
  console.error(
    ""
  );

  for (
    const error of errors
  ) {
    console.error(
      `COVERAGE ERROR: ${error}`
    );
  }

  process.exit(1);
}

console.log(
  "CONTENT COVERAGE VALIDATION: PASS"
);
'@
WriteUtf8 $coverageValidator $validator

# ------------------------------------------------------------------
# 4. Add script without reserialising package.json formatting.
# ------------------------------------------------------------------

$package = Get-Content $packageJson -Raw

if ($package -notmatch '"content:coverage:validate"') {
    $anchor = '"content:eligibility:validate": "node tools/content-compiler/validate-eligibility.mjs",'
    $replacement = $anchor + "`r`n    " + '"content:coverage:validate": "node tools/content-compiler/validate-coverage.mjs",'

    if (-not $package.Contains($anchor)) {
        throw "package.json content validation script anchor not found."
    }

    $package = $package.Replace($anchor,$replacement)
    WriteUtf8 $packageJson $package
}

Write-Host "PASS: parameterised safe-draft authoring added" -ForegroundColor Green
Write-Host "PASS: coverage policy is configuration-driven" -ForegroundColor Green
Write-Host "PASS: validator derives active skills from skill graph" -ForegroundColor Green
Write-Host "PASS: no curriculum claims, skills, prerequisites, or activities invented" -ForegroundColor Green
Write-Host "PASS: no draft content auto-enabled" -ForegroundColor Green

# Existing repository intentionally has visual-discrimination below the
# new minimum. Validate the validator's expected diagnostic separately.
Write-Host ""
Write-Host "==> Coverage validator expected-gap probe" -ForegroundColor Cyan

$old = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $probe = & node $coverageValidator 2>&1
    $probeCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $old
}

foreach ($item in $probe) {
    $text = if ($item -is [System.Management.Automation.ErrorRecord]) {
        $item.Exception.Message
    } else {
        [string]$item
    }
    Write-Host $text
    Log $text
}

if ($probeCode -eq 0) {
    throw "Coverage validator unexpectedly passed the known Phase 008R baseline gap."
}

$probeText = ($probe | ForEach-Object {
    if ($_ -is [System.Management.Automation.ErrorRecord]) {
        $_.Exception.Message
    } else {
        [string]$_
    }
}) -join "`n"

if ($probeText -notmatch "visual-discrimination") {
    throw "Coverage validator failed, but not for the known visual-discrimination coverage gap."
}

Write-Host "PASS: validator detects the known uncovered active skill" -ForegroundColor Green

Native "Content compiler reproducibility" "pnpm content:check"
Native "Content sequencing validation" "pnpm content:sequence:validate"
Native "Content eligibility validation" "pnpm content:eligibility:validate"
Native "Curriculum validation" "pnpm curriculum:validate"
Native "Repository typecheck" "pnpm typecheck"
Native "All tests" "pnpm test"
Native "Production build" "pnpm build"
Native "Frozen lockfile verification" "pnpm install --frozen-lockfile"
Native "Git whitespace check" "git diff --check"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008R1: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Governed bulk-authoring foundation is installed." -ForegroundColor Cyan
Write-Host "Draft activities remain disabled and unreviewed by default." -ForegroundColor Cyan
Write-Host "Coverage policy is data-driven and contains no current skill IDs." -ForegroundColor Cyan
Write-Host "Known visual-discrimination coverage gap is now machine-detectable." -ForegroundColor Cyan
Write-Host "No curriculum claims or new activities were fabricated." -ForegroundColor Cyan
Write-Host "Next phase may author reviewed content to close the measured gap." -ForegroundColor Cyan
Write-Host "Log: $log" -ForegroundColor White
