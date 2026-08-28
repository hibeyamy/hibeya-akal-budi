param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$testPath = Join-Path $root "apps\learner-web\src\shell\LearnerShell.test.tsx"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008a-repair-v2-$runId.log"

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

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`n$Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008a-repair-v2-$stamp-out.log"
  $err = Join-Path $logs "phase008a-repair-v2-$stamp-err.log"

  $p = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err `
    -NoNewWindow `
    -Wait `
    -PassThru

  $o = if (Test-Path $out) { Get-Content $out -Raw } else { "" }
  $e = if (Test-Path $err) { Get-Content $err -Raw } else { "" }

  if ($o) { Write-Host $o; Add-Content $log $o -Encoding UTF8 }
  if ($e) { Write-Host $e; Add-Content $log $e -Encoding UTF8 }

  if ($p.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase008a-repair-v2-$stamp-$($Name.Replace(' ','-')).log"
    WriteText $diag "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$o`n`nSTDERR:`n$e"
    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 008A REPAIR V2: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008A REPAIR V2" -ForegroundColor Cyan
Write-Host "Dependency-free LearnerShell tests" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $testPath)) {
  throw "Missing test file: $testPath"
}

$backup = Join-Path $backups "$runId-LearnerShell.test.tsx"
Copy-Item $testPath $backup -Force
Write-Host "Backup: $backup"

$testSource = @'
import {
  renderToStaticMarkup
} from "react-dom/server";

import {
  describe,
  expect,
  it
} from "vitest";

import {
  LearnerHome,
  LearnerShell
} from "./index";

describe(
  "LearnerShell",
  () => {
    it(
      "shows learner identity and calm progress context",
      () => {
        const html =
          renderToStaticMarkup(
            <LearnerShell
              learnerName="Alya"
              progressPercent={35}
            >
              <LearnerHome />
            </LearnerShell>
          );

        expect(
          html
        ).toContain(
          "Hai, Alya"
        );

        expect(
          html
        ).toContain(
          'aria-label="Kemajuan 35 peratus"'
        );
      }
    );

    it(
      "keeps primary learner actions at least 56px high",
      () => {
        const html =
          renderToStaticMarkup(
            <LearnerHome />
          );

        expect(
          html
        ).toContain(
          "Sambung belajar"
        );

        expect(
          html
        ).toContain(
          "min-h-14"
        );
      }
    );

    it(
      "includes an accessible skip link",
      () => {
        const html =
          renderToStaticMarkup(
            <LearnerShell>
              <LearnerHome />
            </LearnerShell>
          );

        expect(
          html
        ).toContain(
          'href="#learner-main"'
        );

        expect(
          html
        ).toContain(
          'id="learner-main"'
        );
      }
    );
  }
);
'@

WriteText $testPath $testSource
Write-Host "PASS: LearnerShell tests rewritten without @testing-library/react" -ForegroundColor Green

Run "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run "Learner web tests" "pnpm --filter learner-web test"
Run "Storybook production build" "pnpm storybook:build"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression verification" "pnpm qa:visual"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run "Stage Phase 008A repair" "git add apps/learner-web/src/shell/LearnerShell.test.tsx"
  Run "Commit Phase 008A repair" 'git commit -m "test: remove unnecessary learner shell test dependency"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008A REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "No new npm dependency was added." -ForegroundColor Cyan
Write-Host "The existing React + Vitest toolchain now covers these structural shell tests." -ForegroundColor Cyan
