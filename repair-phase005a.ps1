param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$doctorPath = Join-Path $repoRoot "tools\dev\doctor.mjs"
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

  [System.IO.File]::WriteAllText(
    $Path,
    $Content.TrimEnd() + "`n",
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Invoke-Native {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command
  )

  Write-Step $Name

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logsRoot "phase005a-repair-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase005a-repair-$timestamp-err.log"

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
    $diagnostic = Join-Path $logsRoot "FAILED-phase005a-repair-$timestamp-$($Name.Replace(' ','-')).log"

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
Write-Host "HIBEYA AKAL BUDI - PHASE 005A REPAIR" -ForegroundColor Cyan
Write-Host "Windows-safe project doctor" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $doctorPath)) {
  throw "Project doctor not found: $doctorPath"
}

Write-Step "Backing up project doctor"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item `
  $doctorPath `
  (Join-Path $backupRoot "$timestamp-tools__dev__doctor.mjs") `
  -Force


Write-Step "Replacing project doctor with Windows-safe implementation"

$doctor = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import {
  execFileSync,
  execSync
} from "node:child_process";


const repoRoot =
  process.cwd();


const failures =
  [];


function pass(
  message
) {
  console.log(
    `PASS  ${message}`
  );
}


function fail(
  message
) {
  console.error(
    `FAIL  ${message}`
  );

  failures.push(
    message
  );
}


function readText(
  relativePath
) {
  return fs.readFileSync(
    path.join(
      repoRoot,
      relativePath
    ),
    "utf8"
  );
}


function exists(
  relativePath
) {
  return fs.existsSync(
    path.join(
      repoRoot,
      relativePath
    )
  );
}


/**
 * Executes a tool in a cross-platform way.
 *
 * Windows .cmd shims such as pnpm.cmd cannot always be launched
 * directly by execFileSync on newer Node/Windows combinations.
 * Use cmd.exe explicitly on Windows and execFileSync elsewhere.
 */
function runTool(
  command,
  args = []
) {
  if (
    process.platform ===
    "win32"
  ) {
    const quoted =
      [
        command,
        ...args
      ]
        .map(
          value =>
            `"${String(value).replace(/"/g, '""')}"`
        )
        .join(
          " "
        );

    return execFileSync(
      "cmd.exe",
      [
        "/d",
        "/s",
        "/c",
        quoted
      ],
      {
        cwd:
          repoRoot,

        encoding:
          "utf8",

        stdio: [
          "ignore",
          "pipe",
          "pipe"
        ]
      }
    ).trim();
  }


  return execFileSync(
    command,
    args,
    {
      cwd:
        repoRoot,

      encoding:
        "utf8",

      stdio: [
        "ignore",
        "pipe",
        "pipe"
      ]
    }
  ).trim();
}


console.log(
  "HIBEYA AKAL BUDI PROJECT DOCTOR"
);

console.log(
  "================================"
);


const requiredFiles = [
  "package.json",
  "pnpm-lock.yaml",
  "pnpm-workspace.yaml",
  ".node-version",
  ".env.example",
  ".gitattributes",
  "tools/content-compiler/compile.mjs",
  "apps/learner-web/package.json",
  "apps/parent-web/package.json",
  "supabase/config.toml"
];


for (
  const file
  of requiredFiles
) {
  if (
    exists(
      file
    )
  ) {
    pass(
      `required file: ${file}`
    );
  } else {
    fail(
      `missing required file: ${file}`
    );
  }
}


try {
  const expectedNode =
    readText(
      ".node-version"
    ).trim();

  const actualNode =
    process.version;

  if (
    actualNode ===
    expectedNode
  ) {
    pass(
      `Node ${actualNode}`
    );
  } else {
    fail(
      `Node mismatch: expected ${expectedNode}, actual ${actualNode}`
    );
  }
} catch (error) {
  fail(
    `Node check failed: ${error.message}`
  );
}


try {
  const packageJson =
    JSON.parse(
      readText(
        "package.json"
      )
    );

  const expectedPnpm =
    String(
      packageJson.packageManager ??
      ""
    )
      .replace(
        /^pnpm@/,
        ""
      );

  const actualPnpm =
    runTool(
      "pnpm",
      [
        "--version"
      ]
    );

  if (
    expectedPnpm ===
    actualPnpm
  ) {
    pass(
      `pnpm ${actualPnpm}`
    );
  } else {
    fail(
      `pnpm mismatch: expected ${expectedPnpm}, actual ${actualPnpm}`
    );
  }
} catch (error) {
  fail(
    `pnpm check failed: ${error.message}`
  );
}


try {
  const trackedSecrets =
    runTool(
      "git",
      [
        "ls-files",
        ".env",
        ".env.local",
        ".env.security.local"
      ]
    );

  if (
    trackedSecrets.length ===
    0
  ) {
    pass(
      "no known local secret files tracked"
    );
  } else {
    fail(
      `secret files tracked by Git: ${trackedSecrets}`
    );
  }
} catch (error) {
  fail(
    `Git secret check failed: ${error.message}`
  );
}


try {
  runTool(
    "node",
    [
      "tools/content-compiler/compile.mjs",
      "--check"
    ]
  );

  pass(
    "content compiler reproducibility"
  );
} catch {
  fail(
    "content compiler output is out of date"
  );
}


const examplePath =
  path.join(
    repoRoot,
    ".env.example"
  );


if (
  fs.existsSync(
    examplePath
  )
) {
  const envExample =
    fs.readFileSync(
      examplePath,
      "utf8"
    );

  const suspicious =
    envExample
      .split(/\r?\n/)
      .filter(
        line =>
          /^[A-Z][A-Z0-9_]+=.+/.test(
            line
          )
      );

  if (
    suspicious.length ===
    0
  ) {
    pass(
      ".env.example contains no values"
    );
  } else {
    fail(
      ".env.example appears to contain real values"
    );
  }
}


if (
  failures.length >
  0
) {
  console.error("");
  console.error(
    `PROJECT DOCTOR: FAIL (${failures.length})`
  );

  process.exit(1);
}


console.log("");
console.log(
  "PROJECT DOCTOR: PASS"
);
'@

Write-Utf8NoBom `
  -Path $doctorPath `
  -Content $doctor


Invoke-Native `
  -Name "Project doctor" `
  -Command "node tools\dev\doctor.mjs"

Invoke-Native `
  -Name "Content compiler check" `
  -Command "node tools\content-compiler\compile.mjs --check"

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
    -Name "Git stage portability files" `
    -Command "git add .node-version .nvmrc .gitattributes .env.example package.json DEVELOPMENT.md bootstrap-dev.cmd tools\dev\doctor.mjs tools\dev\bootstrap-dev.ps1"

  Invoke-Native `
    -Name "Git commit" `
    -Command 'git commit -m "chore: add reproducible development bootstrap"'
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 005A REPAIR: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
