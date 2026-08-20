param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$toolsRoot = Join-Path $repoRoot "tools\dev"
$logsRoot = Join-Path $toolsRoot "logs"
$backupRoot = Join-Path $toolsRoot "backups"

New-Item -ItemType Directory -Force -Path $toolsRoot | Out-Null
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

function Invoke-Native {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command
  )

  Write-Step $Name

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logsRoot "phase005a-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase005a-$timestamp-err.log"

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
    $diagnostic = Join-Path $logsRoot "FAILED-phase005a-$timestamp-$($Name.Replace(' ','-')).log"

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
Write-Host "HIBEYA AKAL BUDI - PHASE 005A" -ForegroundColor Cyan
Write-Host "Portable & reproducible development environment" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan


# ------------------------------------------------------------
# Detect exact local toolchain versions.
# ------------------------------------------------------------

Write-Step "Detecting toolchain versions"

$nodeVersion =
  (
    node --version
  ).Trim()

if ($LASTEXITCODE -ne 0) {
  throw "Node.js is not available."
}

$pnpmVersion =
  (
    pnpm --version
  ).Trim()

if ($LASTEXITCODE -ne 0) {
  throw "pnpm is not available."
}

Write-Host "Node: $nodeVersion" -ForegroundColor Green
Write-Host "pnpm: $pnpmVersion" -ForegroundColor Green


# ------------------------------------------------------------
# Pin Node version.
# ------------------------------------------------------------

Write-Step "Pinning Node version"

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot ".node-version") `
  -Content $nodeVersion

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot ".nvmrc") `
  -Content $nodeVersion


# ------------------------------------------------------------
# Ensure root package.json has packageManager pinned.
# ------------------------------------------------------------

Write-Step "Pinning pnpm version in package.json"

$packagePath =
  Join-Path $repoRoot "package.json"

if (-not (Test-Path $packagePath)) {
  throw "Root package.json not found."
}

$packageJson =
  Get-Content $packagePath -Raw |
  ConvertFrom-Json

$packageJson |
  Add-Member `
    -NotePropertyName "packageManager" `
    -NotePropertyValue "pnpm@$pnpmVersion" `
    -Force

$packageText =
  $packageJson |
  ConvertTo-Json -Depth 100

Write-Utf8NoBom `
  -Path $packagePath `
  -Content $packageText


# ------------------------------------------------------------
# Generate environment variable inventory from source.
# Values are never copied.
# ------------------------------------------------------------

Write-Step "Generating environment template without secrets"

$scanExtensions = @(
  "*.ts",
  "*.tsx",
  "*.js",
  "*.mjs",
  "*.cjs"
)

$excludedSegments = @(
  "\node_modules\",
  "\dist\",
  "\.git\",
  "\tools\dev\backups\",
  "\tools\dev\logs\"
)

$sourceFiles = @()

foreach ($pattern in $scanExtensions) {
  $sourceFiles +=
    Get-ChildItem `
      -Path $repoRoot `
      -Recurse `
      -File `
      -Filter $pattern `
      -ErrorAction SilentlyContinue |
    Where-Object {
      $full = $_.FullName

      -not (
        $excludedSegments |
        Where-Object {
          $full.Contains($_)
        }
      )
    }
}

$envNames =
  New-Object System.Collections.Generic.HashSet[string]

foreach ($file in $sourceFiles) {
  $text =
    Get-Content `
      $file.FullName `
      -Raw `
      -ErrorAction SilentlyContinue

  if (-not $text) {
    continue
  }

  foreach ($match in [regex]::Matches(
    $text,
    'import\.meta\.env\.([A-Z][A-Z0-9_]+)'
  )) {
    [void]$envNames.Add(
      $match.Groups[1].Value
    )
  }

  foreach ($match in [regex]::Matches(
    $text,
    'process\.env\.([A-Z][A-Z0-9_]+)'
  )) {
    [void]$envNames.Add(
      $match.Groups[1].Value
    )
  }
}

$sortedEnvNames =
  $envNames |
  Sort-Object

$envExampleLines = @(
  "# HIBEYA Akal Budi",
  "# Generated environment-variable template.",
  "# Never put real secrets in this file.",
  ""
)

foreach ($name in $sortedEnvNames) {
  $envExampleLines += "$name="
}

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot ".env.example") `
  -Content (
    $envExampleLines -join "`n"
  )

Write-Host (
  "Environment keys detected: " +
  $sortedEnvNames.Count
) -ForegroundColor Green


# ------------------------------------------------------------
# Git attributes: future line-ending consistency.
# ------------------------------------------------------------

Write-Step "Installing line-ending policy"

$gitattributes = @'
* text=auto

*.ts   text eol=lf
*.tsx  text eol=lf
*.js   text eol=lf
*.mjs  text eol=lf
*.cjs  text eol=lf
*.json text eol=lf
*.sql  text eol=lf
*.md   text eol=lf
*.yml  text eol=lf
*.yaml text eol=lf
*.css  text eol=lf
*.html text eol=lf
*.ps1  text eol=crlf
*.cmd  text eol=crlf
'@

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot ".gitattributes") `
  -Content $gitattributes


# ------------------------------------------------------------
# Doctor script.
# ------------------------------------------------------------

Write-Step "Installing portable project doctor"

$doctor = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";


const repoRoot =
  process.cwd();


function pass(message) {
  console.log(
    `PASS  ${message}`
  );
}


function fail(message) {
  console.error(
    `FAIL  ${message}`
  );

  failures.push(
    message
  );
}


function readText(relativePath) {
  return fs.readFileSync(
    path.join(
      repoRoot,
      relativePath
    ),
    "utf8"
  );
}


function exists(relativePath) {
  return fs.existsSync(
    path.join(
      repoRoot,
      relativePath
    )
  );
}


function run(
  command,
  args
) {
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


const failures =
  [];


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
    run(
      process.platform ===
        "win32"
        ? "pnpm.cmd"
        : "pnpm",
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
    run(
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
  run(
    "node",
    [
      "tools/content-compiler/compile.mjs",
      "--check"
    ]
  );

  pass(
    "content compiler reproducibility"
  );
} catch (error) {
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
  -Path (Join-Path $toolsRoot "doctor.mjs") `
  -Content $doctor


# ------------------------------------------------------------
# Portable bootstrap script.
# ------------------------------------------------------------

Write-Step "Installing bootstrap-dev"

$bootstrapPs1 = @'
param(
  [switch]$SkipInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot =
  (
    Resolve-Path (
      Join-Path `
        $PSScriptRoot `
        "..\.."
    )
  ).Path

Set-Location $repoRoot

Write-Host ""
Write-Host "HIBEYA AKAL BUDI - DEV BOOTSTRAP" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

if (
  -not (
    Get-Command node -ErrorAction SilentlyContinue
  )
) {
  throw "Node.js is not installed."
}

if (
  -not (
    Get-Command pnpm -ErrorAction SilentlyContinue
  )
) {
  throw "pnpm is not available. Install/enable Corepack and the pinned pnpm version first."
}

node tools/dev/doctor.mjs

if ($LASTEXITCODE -ne 0) {
  throw "Project doctor failed before dependency installation."
}

if (
  -not $SkipInstall
) {
  Write-Host ""
  Write-Host "Installing dependencies from lockfile..." -ForegroundColor Cyan

  pnpm install --frozen-lockfile

  if ($LASTEXITCODE -ne 0) {
    throw "pnpm install failed."
  }
}

Write-Host ""
Write-Host "Running validation..." -ForegroundColor Cyan

pnpm typecheck
if ($LASTEXITCODE -ne 0) {
  throw "Typecheck failed."
}

pnpm test
if ($LASTEXITCODE -ne 0) {
  throw "Tests failed."
}

pnpm build
if ($LASTEXITCODE -ne 0) {
  throw "Build failed."
}

node tools/content-compiler/compile.mjs --check
if ($LASTEXITCODE -ne 0) {
  throw "Content compiler check failed."
}

pnpm supabase db push --dry-run
if ($LASTEXITCODE -ne 0) {
  throw "Supabase migration dry-run failed."
}

git diff --check
if ($LASTEXITCODE -ne 0) {
  throw "Git whitespace validation failed."
}

Write-Host ""
Write-Host "BOOTSTRAP VALIDATION: PASS" -ForegroundColor Green
'@

Write-Utf8NoBom `
  -Path (Join-Path $toolsRoot "bootstrap-dev.ps1") `
  -Content $bootstrapPs1


$bootstrapCmd = @'
@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\dev\bootstrap-dev.ps1" %*
set EXITCODE=%ERRORLEVEL%
exit /b %EXITCODE%
'@

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot "bootstrap-dev.cmd") `
  -Content $bootstrapCmd


# ------------------------------------------------------------
# Development documentation.
# ------------------------------------------------------------

Write-Step "Writing portable development guide"

$developmentMd = @"
# HIBEYA Akal Budi — Development Environment

## Required toolchain

- Node.js: $nodeVersion
- pnpm: $pnpmVersion
- Git
- Supabase CLI through the project dependency / pnpm workflow

## New machine setup

1. Clone the private repository.
2. Enter the repository directory.
3. Create local environment files from `.env.example`.
4. Obtain actual secret values through an approved secure channel.
5. Never commit local `.env` files.
6. Run:

````powershell
.\bootstrap-dev.cmd
````

The bootstrap validates:

- Node version
- pnpm version
- required project files
- secret-file Git safety
- manifest compiler reproducibility
- dependency installation from the lockfile
- TypeScript
- tests
- production builds
- Supabase migration dry-run
- Git whitespace rules

## Content workflow

Create a draft manifest:

````powershell
node tools\content-compiler\new-activity.mjs activity-id
````

Compile manifests:

````powershell
node tools\content-compiler\compile.mjs
````

Verify no generated drift:

````powershell
node tools\content-compiler\compile.mjs --check
````

## Environment files

`.env.example` contains variable names only.

Real values belong in local ignored environment files and must never be committed.

## Portability principle

A development machine is disposable.

The reproducible source of truth consists of:

- Git repository
- lockfile
- pinned toolchain versions
- migrations
- manifests
- generated-source checks
- secure environment configuration

No commercial project knowledge should exist only on one laptop.
"@

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot "DEVELOPMENT.md") `
  -Content $developmentMd


# ------------------------------------------------------------
# Validate the portability layer.
# ------------------------------------------------------------

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
    -Name "Git stage" `
    -Command "git add .node-version .nvmrc .gitattributes .env.example package.json DEVELOPMENT.md bootstrap-dev.cmd tools\dev\doctor.mjs tools\dev\bootstrap-dev.ps1"

  Invoke-Native `
    -Name "Git commit" `
    -Command 'git commit -m "chore: add reproducible development bootstrap"'
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 005A: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next step after commit/push:" -ForegroundColor White
Write-Host "  Fresh-clone verification on a clean directory or second laptop." -ForegroundColor Cyan
