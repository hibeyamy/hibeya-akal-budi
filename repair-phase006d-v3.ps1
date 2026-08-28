param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$qaRoot = Join-Path $repoRoot "tools\visual-regression"
$serverPath = Join-Path $qaRoot "serve-storybook.mjs"
$configPath = Join-Path $qaRoot "playwright.config.ts"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$sessionLog = Join-Path $logsRoot "phase006d-repair-v3-$runId.log"

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

function Invoke-Native {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command
  )

  Log ""
  Log "==> $Name"
  Log "COMMAND: $Command"

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logsRoot "phase006d-v3-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase006d-v3-$timestamp-err.log"

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

  if ($outText) {
    Write-Host $outText
    Add-Content -Path $sessionLog -Value $outText -Encoding UTF8
  }

  if ($errText) {
    Write-Host $errText
    Add-Content -Path $sessionLog -Value $errText -Encoding UTF8
  }

  if ($process.ExitCode -ne 0) {
    $diagnostic = Join-Path $logsRoot "FAILED-phase006d-v3-$timestamp-$($Name.Replace(' ','-')).log"

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

  Log "PASS: $Name"
}

trap {
  $details = @"
PHASE 006D REPAIR V3 FAILED

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

  Write-Utf8NoBom -Path $sessionLog -Content $details

  Write-Host ""
  Write-Host "PHASE 006D REPAIR V3: FAILED" -ForegroundColor Red
  Write-Host "Diagnostic: $sessionLog" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006D REPAIR V3" -ForegroundColor Cyan
Write-Host "Fix Storybook server repository-root resolution" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $configPath)) {
  throw "Missing Playwright config: $configPath"
}

# The previous server used process.cwd(), but Playwright launches the
# webServer command with the config directory as cwd. Resolve the repo
# from this module's own file location instead, which is portable.
$serverSource = @'
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const currentFile =
  fileURLToPath(
    import.meta.url
  );

const currentDir =
  path.dirname(
    currentFile
  );

const repoRoot =
  path.resolve(
    currentDir,
    "..",
    ".."
  );

const root =
  path.join(
    repoRoot,
    "apps",
    "ui-storybook",
    "storybook-static"
  );

const port =
  Number(
    process.env.STORYBOOK_TEST_PORT ??
    6106
  );

const mime =
  new Map([
    [".html", "text/html; charset=utf-8"],
    [".js", "text/javascript; charset=utf-8"],
    [".mjs", "text/javascript; charset=utf-8"],
    [".css", "text/css; charset=utf-8"],
    [".json", "application/json; charset=utf-8"],
    [".svg", "image/svg+xml"],
    [".png", "image/png"],
    [".jpg", "image/jpeg"],
    [".jpeg", "image/jpeg"],
    [".webp", "image/webp"],
    [".woff2", "font/woff2"]
  ]);

if (
  !fs.existsSync(
    root
  )
) {
  console.error(
    `Storybook static build is missing: ${root}`
  );

  process.exit(1);
}

function resolveSafe(
  requestPath
) {
  const raw =
    decodeURIComponent(
      requestPath.split("?")[0]
    );

  const requested =
    raw === "/"
      ? "/index.html"
      : raw;

  const resolved =
    path.resolve(
      root,
      "." + requested
    );

  const normalisedRoot =
    path.resolve(
      root
    );

  if (
    resolved !== normalisedRoot &&
    !resolved.startsWith(
      normalisedRoot +
      path.sep
    )
  ) {
    return null;
  }

  return resolved;
}

const server =
  http.createServer(
    (
      request,
      response
    ) => {
      const resolved =
        resolveSafe(
          request.url ??
          "/"
        );

      if (!resolved) {
        response.writeHead(403);
        response.end("Forbidden");
        return;
      }

      let file =
        resolved;

      if (
        fs.existsSync(file) &&
        fs.statSync(file).isDirectory()
      ) {
        file =
          path.join(
            file,
            "index.html"
          );
      }

      if (
        !fs.existsSync(
          file
        )
      ) {
        response.writeHead(404);
        response.end("Not found");
        return;
      }

      response.setHeader(
        "Cache-Control",
        "no-store"
      );

      response.setHeader(
        "Content-Type",
        mime.get(
          path.extname(
            file
          ).toLowerCase()
        ) ??
        "application/octet-stream"
      );

      fs.createReadStream(
        file
      ).pipe(
        response
      );
    }
  );

server.listen(
  port,
  "127.0.0.1",
  () => {
    console.log(
      `Storybook test server: http://127.0.0.1:${port}`
    );

    console.log(
      `Serving: ${root}`
    );
  }
);
'@

Write-Utf8NoBom `
  -Path $serverPath `
  -Content $serverSource

Log "PASS: Storybook server root resolution repaired"

$browserPath =
  [Environment]::GetEnvironmentVariable(
    "PLAYWRIGHT_BROWSERS_PATH",
    "User"
  )

if ([string]::IsNullOrWhiteSpace($browserPath)) {
  $browserPath = "D:\Development\playwright"
}

$env:PLAYWRIGHT_BROWSERS_PATH = $browserPath
Log "Playwright browsers: $browserPath"

# The Storybook build already passed in V2, but rebuild once to guarantee
# the static output exists at the expected D: location.
Invoke-Native `
  -Name "Storybook production build" `
  -Command "pnpm storybook:build"

Invoke-Native `
  -Name "Accessibility regression" `
  -Command "pnpm qa:a11y"

$snapshotRoot =
  Join-Path `
    $qaRoot `
    "tests\visual.spec.ts-snapshots"

if (-not (Test-Path $snapshotRoot)) {
  Invoke-Native `
    -Name "Create initial visual baselines" `
    -Command "pnpm qa:visual:update"
}
else {
  Log ""
  Log "Existing visual baselines found; they will NOT be overwritten."
}

Invoke-Native `
  -Name "Visual regression verification" `
  -Command "pnpm qa:visual"

Invoke-Native `
  -Name "Design adoption validation" `
  -Command "pnpm design:apps:validate"

Invoke-Native `
  -Name "Design policy validation" `
  -Command "pnpm design:validate"

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

if ($Commit) {
  Invoke-Native `
    -Name "Stage Phase 006D" `
    -Command "git add tools/visual-regression ACCESSIBILITY_VISUAL_QA.md package.json pnpm-lock.yaml"

  Invoke-Native `
    -Name "Commit Phase 006D" `
    -Command 'git commit -m "test: add accessibility and visual regression gates"'
}

Log ""
Log "PHASE 006D REPAIR V3: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006D: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Log: $sessionLog" -ForegroundColor DarkGray
