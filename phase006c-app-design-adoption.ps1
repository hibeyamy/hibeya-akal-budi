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

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$sessionLog = Join-Path $logsRoot "phase006c-$runId.log"

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )

  $dir = Split-Path -Parent $Path

  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

  [System.IO.File]::WriteAllText(
    $Path,
    $Content.TrimEnd() + "`n",
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Log {
  param([string]$Message)

  Write-Host $Message
  Add-Content -Path $sessionLog -Value $Message -Encoding UTF8
}

function Backup-File {
  param(
    [Parameter(Mandatory)][string]$Path
  )

  if (-not (Test-Path $Path)) {
    return
  }

  $relative =
    $Path.Substring(
      $repoRoot.Length
    ).TrimStart("\")

  $safe =
    $relative.Replace(
      "\",
      "__"
    )

  Copy-Item `
    $Path `
    (Join-Path $backupRoot "$runId-$safe") `
    -Force
}

function Invoke-Native {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command
  )

  Log ""
  Log "==> $Name"

  $timestamp =
    Get-Date -Format "yyyyMMdd-HHmmssfff"

  $stdout =
    Join-Path $logsRoot "phase006c-$timestamp-out.log"

  $stderr =
    Join-Path $logsRoot "phase006c-$timestamp-err.log"

  $process =
    Start-Process `
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

  $outText =
    if (Test-Path $stdout) {
      Get-Content $stdout -Raw
    }
    else {
      ""
    }

  $errText =
    if (Test-Path $stderr) {
      Get-Content $stderr -Raw
    }
    else {
      ""
    }

  if ($outText) {
    Write-Host $outText
    Add-Content -Path $sessionLog -Value $outText -Encoding UTF8
  }

  if ($errText) {
    Write-Host $errText
    Add-Content -Path $sessionLog -Value $errText -Encoding UTF8
  }

  if (
    $process.ExitCode -ne 0
  ) {
    $diagnostic =
      Join-Path `
        $logsRoot `
        "FAILED-phase006c-$timestamp-$($Name.Replace(' ','-')).log"

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

  Remove-Item `
    $stdout,$stderr `
    -Force `
    -ErrorAction SilentlyContinue

  Log "PASS: $Name"
}

function Patch-MainEntry {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][ValidateSet("learner","parent")][string]$Audience
  )

  if (-not (Test-Path $Path)) {
    throw "Application entrypoint not found: $Path"
  }

  Backup-File -Path $Path

  $content =
    Get-Content `
      $Path `
      -Raw

  $tokenImport =
    'import "@akal-budi/design-system/tokens.css";'

  $uiImport =
    'import "@akal-budi/ui/styles.css";'

  if (
    -not $content.Contains(
      $tokenImport
    )
  ) {
    $content =
      $tokenImport +
      "`n" +
      $content
  }

  if (
    -not $content.Contains(
      $uiImport
    )
  ) {
    $content =
      $uiImport +
      "`n" +
      $content
  }

  $audienceLine =
    'document.documentElement.dataset.abAudience = "' +
    $Audience +
    '";'

  if (
    -not $content.Contains(
      $audienceLine
    )
  ) {
    $lastImport =
      [regex]::Matches(
        $content,
        '(?m)^import .*?;\s*$'
      ) |
      Select-Object `
        -Last 1

    if (
      $null -ne $lastImport
    ) {
      $insertAt =
        $lastImport.Index +
        $lastImport.Length

      $content =
        $content.Insert(
          $insertAt,
          "`n`n$audienceLine"
        )
    }
    else {
      $content =
        $audienceLine +
        "`n`n" +
        $content
    }
  }

  Write-Utf8NoBom `
    -Path $Path `
    -Content $content
}

trap {
  $details = @"
PHASE 006C FAILED

TIME:
$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")

MESSAGE:
$($_.Exception.Message)

ERROR:
$($_ | Out-String)

POSITION:
$($_.InvocationInfo.PositionMessage)

STACK:
$($_.ScriptStackTrace)
"@

  Write-Utf8NoBom `
    -Path $sessionLog `
    -Content $details

  Write-Host ""
  Write-Host "Phase 006C failed." -ForegroundColor Red
  Write-Host "Diagnostic: $sessionLog" -ForegroundColor Yellow

  exit 1
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006C" -ForegroundColor Cyan
Write-Host "Learner + Parent Design Token Adoption" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"


# ============================================================
# 1. Verify prerequisites.
# ============================================================

Log ""
Log "==> Verifying Phase 006 prerequisites"

$designPackagePath =
  Join-Path `
    $repoRoot `
    "packages\design-system\package.json"

$designTokensPath =
  Join-Path `
    $repoRoot `
    "packages\design-system\src\tokens.css"

$uiPackagePath =
  Join-Path `
    $repoRoot `
    "packages\ui\package.json"

$uiStylesPath =
  Join-Path `
    $repoRoot `
    "packages\ui\src\styles.css"

foreach (
  $required
  in @(
    $designPackagePath,
    $designTokensPath,
    $uiPackagePath,
    $uiStylesPath
  )
) {
  if (
    -not (Test-Path $required)
  ) {
    throw "Required Phase 006 prerequisite is missing: $required"
  }
}

Log "PASS: Phase 006A/006B prerequisites exist"


# ============================================================
# 2. Export design-system CSS through package.json.
#    Use a temporary Node file to avoid PowerShell JSON pitfalls.
# ============================================================

Log ""
Log "==> Exporting semantic token CSS"

Backup-File -Path $designPackagePath

$tempEditor =
  Join-Path `
    $env:TEMP `
    "akal-budi-phase006c-package-editor.cjs"

$editorSource = @'
const fs = require("fs");

const [
  ,
  ,
  designPackagePath,
  learnerPackagePath,
  parentPackagePath,
  rootPackagePath
] = process.argv;

function read(path) {
  return JSON.parse(
    fs.readFileSync(
      path,
      "utf8"
    )
  );
}

function write(path, value) {
  fs.writeFileSync(
    path,
    JSON.stringify(
      value,
      null,
      2
    ) + "\n",
    "utf8"
  );
}

const design =
  read(
    designPackagePath
  );

design.exports ??= {};

if (
  typeof design.exports ===
  "string"
) {
  design.exports = {
    ".":
      design.exports
  };
}

design.exports["./tokens.css"] =
  "./src/tokens.css";

write(
  designPackagePath,
  design
);


for (
  const packagePath
  of [
    learnerPackagePath,
    parentPackagePath
  ]
) {
  const pkg =
    read(
      packagePath
    );

  pkg.dependencies ??= {};

  pkg.dependencies["@akal-budi/design-system"] =
    "workspace:*";

  pkg.dependencies["@akal-budi/ui"] =
    "workspace:*";

  write(
    packagePath,
    pkg
  );
}


const root =
  read(
    rootPackagePath
  );

root.scripts ??= {};

root.scripts["design:apps:check"] =
  "pnpm --filter learner-web typecheck && pnpm --filter parent-web build";

write(
  rootPackagePath,
  root
);
'@

Write-Utf8NoBom `
  -Path $tempEditor `
  -Content $editorSource

$learnerPackagePath =
  Join-Path `
    $repoRoot `
    "apps\learner-web\package.json"

$parentPackagePath =
  Join-Path `
    $repoRoot `
    "apps\parent-web\package.json"

$rootPackagePath =
  Join-Path `
    $repoRoot `
    "package.json"

foreach (
  $packageFile
  in @(
    $learnerPackagePath,
    $parentPackagePath,
    $rootPackagePath
  )
) {
  if (
    -not (Test-Path $packageFile)
  ) {
    throw "Required package.json not found: $packageFile"
  }

  Backup-File -Path $packageFile
}

& node `
  $tempEditor `
  $designPackagePath `
  $learnerPackagePath `
  $parentPackagePath `
  $rootPackagePath

if (
  $LASTEXITCODE -ne 0
) {
  throw "Package metadata update failed."
}

Remove-Item `
  $tempEditor `
  -Force `
  -ErrorAction SilentlyContinue

Log "PASS: package exports and workspace dependencies updated"


# ============================================================
# 3. Find app entrypoints safely.
# ============================================================

Log ""
Log "==> Resolving application entrypoints"

function Resolve-AppMain {
  param(
    [Parameter(Mandatory)][string]$AppRoot
  )

  foreach (
    $candidate
    in @(
      "src\main.tsx",
      "src\main.ts",
      "src\index.tsx",
      "src\index.ts"
    )
  ) {
    $path =
      Join-Path `
        $AppRoot `
        $candidate

    if (
      Test-Path $path
    ) {
      return $path
    }
  }

  throw "Could not find app entrypoint below $AppRoot"
}

$learnerRoot =
  Join-Path `
    $repoRoot `
    "apps\learner-web"

$parentRoot =
  Join-Path `
    $repoRoot `
    "apps\parent-web"

$learnerMain =
  Resolve-AppMain `
    -AppRoot $learnerRoot

$parentMain =
  Resolve-AppMain `
    -AppRoot $parentRoot

Log "Learner entrypoint: $learnerMain"
Log "Parent entrypoint: $parentMain"


# ============================================================
# 4. Apply semantic token styles and audience contract.
# ============================================================

Log ""
Log "==> Adopting design system in learner app"

Patch-MainEntry `
  -Path $learnerMain `
  -Audience "learner"

Log "PASS: learner app adopted semantic tokens"

Log ""
Log "==> Adopting design system in parent app"

Patch-MainEntry `
  -Path $parentMain `
  -Audience "parent"

Log "PASS: parent app adopted semantic tokens"


# ============================================================
# 5. Create migration guard.
#    This phase intentionally does NOT rewrite existing Tailwind
#    classes yet. It establishes the shared runtime layer first.
# ============================================================

Log ""
Log "==> Creating app design-adoption validator"

$toolRoot =
  Join-Path `
    $repoRoot `
    "tools\design"

New-Item `
  -ItemType Directory `
  -Force `
  -Path $toolRoot `
  | Out-Null

$validator = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root =
  process.cwd();

const apps = [
  {
    id:
      "learner",

    root:
      path.join(
        root,
        "apps",
        "learner-web",
        "src"
      ),

    audience:
      "learner"
  },
  {
    id:
      "parent",

    root:
      path.join(
        root,
        "apps",
        "parent-web",
        "src"
      ),

    audience:
      "parent"
  }
];

const failures = [];

function fail(
  message
) {
  failures.push(
    message
  );

  console.error(
    `DESIGN ADOPTION ERROR: ${message}`
  );
}

function sourceFiles(
  directory
) {
  const result = [];

  for (
    const entry
    of fs.readdirSync(
      directory,
      {
        withFileTypes:
          true
      }
    )
  ) {
    const full =
      path.join(
        directory,
        entry.name
      );

    if (
      entry.isDirectory()
    ) {
      result.push(
        ...sourceFiles(
          full
        )
      );

      continue;
    }

    if (
      /\.(ts|tsx)$/.test(
        entry.name
      )
    ) {
      result.push(
        full
      );
    }
  }

  return result;
}

for (
  const app
  of apps
) {
  if (
    !fs.existsSync(
      app.root
    )
  ) {
    fail(
      `${app.id}: source root missing`
    );

    continue;
  }

  const files =
    sourceFiles(
      app.root
    );

  const all =
    files
      .map(
        file =>
          fs.readFileSync(
            file,
            "utf8"
          )
      )
      .join(
        "\n"
      );

  if (
    !all.includes(
      '@akal-budi/design-system/tokens.css'
    )
  ) {
    fail(
      `${app.id}: semantic token CSS is not imported`
    );
  }

  if (
    !all.includes(
      '@akal-budi/ui/styles.css'
    )
  ) {
    fail(
      `${app.id}: shared UI CSS is not imported`
    );
  }

  const audienceMarker =
    `dataset.abAudience = "${app.audience}"`;

  if (
    !all.includes(
      audienceMarker
    )
  ) {
    fail(
      `${app.id}: expected audience marker ${app.audience}`
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
  "APP DESIGN ADOPTION: PASS"
);
'@

Write-Utf8NoBom `
  -Path (Join-Path $toolRoot "validate-app-adoption.mjs") `
  -Content $validator


# ============================================================
# 6. Add validator command to root package.
# ============================================================

Log ""
Log "==> Registering design adoption validator"

$tempRootEditor =
  Join-Path `
    $env:TEMP `
    "akal-budi-phase006c-root-editor.cjs"

$rootEditorSource = @'
const fs = require("fs");

const path =
  process.argv[2];

const pkg =
  JSON.parse(
    fs.readFileSync(
      path,
      "utf8"
    )
  );

pkg.scripts ??= {};

pkg.scripts["design:apps:validate"] =
  "node tools/design/validate-app-adoption.mjs";

fs.writeFileSync(
  path,
  JSON.stringify(
    pkg,
    null,
    2
  ) + "\n",
  "utf8"
);
'@

Write-Utf8NoBom `
  -Path $tempRootEditor `
  -Content $rootEditorSource

& node `
  $tempRootEditor `
  $rootPackagePath

if (
  $LASTEXITCODE -ne 0
) {
  throw "Could not register design adoption validator."
}

Remove-Item `
  $tempRootEditor `
  -Force `
  -ErrorAction SilentlyContinue

Log "PASS: design adoption validator registered"


# ============================================================
# 7. Workspace install + quality gates.
# ============================================================

Invoke-Native `
  -Name "Workspace install" `
  -Command "pnpm install"

Invoke-Native `
  -Name "App design adoption validation" `
  -Command "pnpm design:apps:validate"

Invoke-Native `
  -Name "Design policy validation" `
  -Command "pnpm design:validate"

Invoke-Native `
  -Name "Learner app typecheck" `
  -Command "pnpm --filter learner-web typecheck"

Invoke-Native `
  -Name "Parent app build" `
  -Command "pnpm --filter parent-web build"

Invoke-Native `
  -Name "Repository typecheck" `
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
  -Name "Content compiler check" `
  -Command "pnpm content:check"

Invoke-Native `
  -Name "Curriculum validation" `
  -Command "pnpm curriculum:validate"

Invoke-Native `
  -Name "Curriculum source validation" `
  -Command "pnpm curriculum:sources:validate"

Invoke-Native `
  -Name "Git whitespace check" `
  -Command "git diff --check"


# ============================================================
# 8. Optional commit.
# ============================================================

if ($Commit) {
  Invoke-Native `
    -Name "Git stage" `
    -Command "git add packages/design-system apps/learner-web apps/parent-web tools/design package.json pnpm-lock.yaml"

  Invoke-Native `
    -Name "Git commit" `
    -Command 'git commit -m "feat: adopt shared design system across apps"'
}


Log ""
Log "PHASE 006C: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006C: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Phase 006D Accessibility + Visual Regression Foundation." -ForegroundColor Cyan
Write-Host "Log: $sessionLog" -ForegroundColor DarkGray
