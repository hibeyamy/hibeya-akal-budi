param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$appRoot = Join-Path $root "apps\learner-web\src"
$shellRoot = Join-Path $appRoot "shell"

New-Item -ItemType Directory -Force -Path $logs,$backups,$shellRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008a-$runId.log"

function WriteText([string]$Path,[string]$Content) {
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  [IO.File]::WriteAllText($Path,$Content.TrimEnd()+"`n",[Text.UTF8Encoding]::new($false))
}

function Backup([string]$Path) {
  if (-not (Test-Path $Path)) { return }
  $relative = $Path.Substring($root.Length).TrimStart("\")
  $safe = $relative.Replace("\","__")
  Copy-Item $Path (Join-Path $backups "$runId-$safe") -Force
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`n$Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008a-$stamp-out.log"
  $err = Join-Path $logs "phase008a-$stamp-err.log"

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
    $diag = Join-Path $logs "FAILED-phase008a-$stamp-$($Name.Replace(' ','-')).log"
    WriteText $diag "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$o`n`nSTDERR:`n$e"
    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 008A: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008A" -ForegroundColor Cyan
Write-Host "Learner UX Shell Foundation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# 1. Add production learner shell components.
# ------------------------------------------------------------------

WriteText (Join-Path $shellRoot "LearnerShell.tsx") @'
import type {
  ReactNode
} from "react";

export interface LearnerShellProps {
  children:
    ReactNode;

  learnerName?:
    string;

  progressPercent?:
    number;

  title?:
    string;

  subtitle?:
    string;
}

export function LearnerShell({
  children,
  learnerName = "Kawan kecil",
  progressPercent = 0,
  title = "Jom belajar!",
  subtitle = "Pilih aktiviti yang sesuai untuk hari ini."
}: LearnerShellProps) {
  const safeProgress =
    Math.min(
      100,
      Math.max(
        0,
        progressPercent
      )
    );

  return (
    <div className="min-h-screen bg-amber-50 text-slate-800">
      <a
        href="#learner-main"
        className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-xl focus:bg-white focus:px-4 focus:py-3 focus:shadow-lg"
      >
        Lompat ke kandungan utama
      </a>

      <header className="border-b border-amber-100 bg-white/95 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-4 sm:px-6">
          <div>
            <p className="text-sm font-semibold text-amber-700">
              HIBEYA Akal Budi
            </p>

            <p className="text-lg font-bold text-slate-900">
              Hai, {learnerName}
            </p>
          </div>

          <div
            className="min-w-32 sm:min-w-48"
            aria-label={`Kemajuan ${Math.round(safeProgress)} peratus`}
          >
            <div className="mb-1 flex items-center justify-between gap-3 text-xs font-semibold text-slate-600">
              <span>
                Kemajuan
              </span>

              <span>
                {Math.round(safeProgress)}%
              </span>
            </div>

            <div className="h-3 overflow-hidden rounded-full bg-slate-100">
              <div
                className="h-full rounded-full bg-amber-500 transition-[width] motion-reduce:transition-none"
                style={{
                  width:
                    `${safeProgress}%`
                }}
              />
            </div>
          </div>
        </div>
      </header>

      <main
        id="learner-main"
        className="mx-auto w-full max-w-6xl px-4 py-6 sm:px-6 sm:py-8"
      >
        <section className="mb-6 rounded-3xl bg-white p-6 shadow-sm ring-1 ring-amber-100 sm:p-8">
          <h1 className="text-3xl font-black tracking-tight text-slate-900 sm:text-4xl">
            {title}
          </h1>

          <p className="mt-2 max-w-2xl text-base font-medium leading-7 text-slate-600 sm:text-lg">
            {subtitle}
          </p>
        </section>

        {children}
      </main>

      <footer className="mt-10 border-t border-amber-100 bg-white">
        <div className="mx-auto max-w-6xl px-4 py-6 text-center text-sm font-medium text-slate-500 sm:px-6">
          Belajar dengan tenang, satu langkah pada satu masa.
        </div>
      </footer>
    </div>
  );
}
'@

WriteText (Join-Path $shellRoot "LearnerHome.tsx") @'
export interface LearnerHomeProps {
  onContinue?:
    () => void;

  onExplore?:
    () => void;
}

export function LearnerHome({
  onContinue,
  onExplore
}: LearnerHomeProps) {
  return (
    <div className="grid gap-5 lg:grid-cols-[1.4fr_1fr]">
      <section className="rounded-3xl bg-white p-6 shadow-sm ring-1 ring-slate-100 sm:p-8">
        <p className="text-sm font-bold uppercase tracking-wide text-amber-700">
          Aktiviti seterusnya
        </p>

        <h2 className="mt-2 text-2xl font-black text-slate-900">
          Warna di sekeliling kita
        </h2>

        <p className="mt-3 max-w-xl text-base leading-7 text-slate-600">
          Kenal warna melalui objek yang dekat dengan kehidupan harian.
        </p>

        <button
          type="button"
          onClick={onContinue}
          className="mt-6 min-h-14 rounded-2xl bg-amber-500 px-6 py-3 text-lg font-extrabold text-slate-950 shadow-sm transition hover:bg-amber-400 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-amber-300 motion-reduce:transition-none"
        >
          Sambung belajar
        </button>
      </section>

      <section className="rounded-3xl bg-white p-6 shadow-sm ring-1 ring-slate-100 sm:p-8">
        <p className="text-sm font-bold uppercase tracking-wide text-emerald-700">
          Teroka
        </p>

        <h2 className="mt-2 text-2xl font-black text-slate-900">
          Aktiviti lain
        </h2>

        <p className="mt-3 text-base leading-7 text-slate-600">
          Pilih aktiviti mengikut minat tanpa tekanan atau ganjaran berlebihan.
        </p>

        <button
          type="button"
          onClick={onExplore}
          className="mt-6 min-h-14 rounded-2xl border-2 border-emerald-300 bg-emerald-50 px-6 py-3 text-lg font-extrabold text-emerald-900 transition hover:bg-emerald-100 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-emerald-200 motion-reduce:transition-none"
        >
          Lihat aktiviti
        </button>
      </section>
    </div>
  );
}
'@

WriteText (Join-Path $shellRoot "index.ts") @'
export {
  LearnerShell,
  type LearnerShellProps
} from "./LearnerShell";

export {
  LearnerHome,
  type LearnerHomeProps
} from "./LearnerHome";
'@

# ------------------------------------------------------------------
# 2. Add Storybook review without touching production routing.
# ------------------------------------------------------------------

WriteText (Join-Path $root "apps\ui-storybook\stories\LearnerShell.stories.tsx") @'
import {
  LearnerHome,
  LearnerShell
} from "../../learner-web/src/shell";

export default {
  title:
    "Learner/UX Shell"
};

export function Default() {
  return (
    <LearnerShell
      learnerName="Alya"
      progressPercent={35}
    >
      <LearnerHome />
    </LearnerShell>
  );
}

export function NewLearner() {
  return (
    <LearnerShell
      learnerName="Adam"
      progressPercent={0}
      title="Selamat datang!"
      subtitle="Mari mula dengan satu aktiviti ringkas."
    >
      <LearnerHome />
    </LearnerShell>
  );
}

export function ReturningLearner() {
  return (
    <LearnerShell
      learnerName="Sofia"
      progressPercent={72}
      title="Bagus, sambung bila bersedia."
      subtitle="Kemajuan disimpan. Tiada tekanan untuk habiskan semuanya hari ini."
    >
      <LearnerHome />
    </LearnerShell>
  );
}
'@

# ------------------------------------------------------------------
# 3. Add focused tests.
# ------------------------------------------------------------------

WriteText (Join-Path $shellRoot "LearnerShell.test.tsx") @'
import {
  render,
  screen
} from "@testing-library/react";

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
        render(
          <LearnerShell
            learnerName="Alya"
            progressPercent={35}
          >
            <LearnerHome />
          </LearnerShell>
        );

        expect(
          screen.getByText(
            "Hai, Alya"
          )
        ).toBeTruthy();

        expect(
          screen.getByLabelText(
            "Kemajuan 35 peratus"
          )
        ).toBeTruthy();
      }
    );

    it(
      "keeps primary learner actions at least 56px high",
      () => {
        render(
          <LearnerHome />
        );

        const button =
          screen.getByRole(
            "button",
            {
              name:
                "Sambung belajar"
            }
          );

        expect(
          button.className
        ).toContain(
          "min-h-14"
        );
      }
    );
  }
);
'@

# ------------------------------------------------------------------
# 4. Validate prerequisites only; do not patch main.tsx blindly.
# ------------------------------------------------------------------

$mainPath = Join-Path $appRoot "main.tsx"

if (-not (Test-Path $mainPath)) {
  throw "learner-web main.tsx is missing"
}

Write-Host ""
Write-Host "Production integration intentionally deferred until the shell passes Storybook/QA." -ForegroundColor Yellow
Write-Host "No blind patch is being applied to main.tsx." -ForegroundColor Yellow

# ------------------------------------------------------------------
# 5. QA gates.
# ------------------------------------------------------------------

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
  Run "Stage Phase 008A" "git add apps/learner-web/src/shell apps/ui-storybook/stories/LearnerShell.stories.tsx"
  Run "Commit Phase 008A" 'git commit -m "feat: add learner UX shell foundation"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008A: PASS - SHELL READY FOR VISUAL REVIEW" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Manual visual review:" -ForegroundColor Cyan
Write-Host "  pnpm storybook" -ForegroundColor White
Write-Host "Open: Learner -> UX Shell" -ForegroundColor White
Write-Host ""
Write-Host "After visual approval, Phase 008A-B will integrate the shell with the actual learner runtime." -ForegroundColor Cyan
