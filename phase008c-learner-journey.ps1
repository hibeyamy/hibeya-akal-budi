param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$src = Join-Path $root "apps\learner-web\src"
$journeyRoot = Join-Path $src "journey"

New-Item -ItemType Directory -Force -Path $logs,$backups,$journeyRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008c-$runId.log"

function WriteText([string]$Path,[string]$Content) {
  $dir = Split-Path -Parent $Path

  if (
    $dir -and
    -not (Test-Path $dir)
  ) {
    New-Item `
      -ItemType Directory `
      -Force `
      -Path $dir |
      Out-Null
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

  Add-Content `
    $log `
    "`n==> $Name`nCOMMAND: $Command" `
    -Encoding UTF8

  $stamp =
    Get-Date `
      -Format "yyyyMMdd-HHmmssfff"

  $out =
    Join-Path `
      $logs `
      "phase008c-$stamp-out.log"

  $err =
    Join-Path `
      $logs `
      "phase008c-$stamp-err.log"

  $process =
    Start-Process `
      -FilePath "cmd.exe" `
      -ArgumentList @(
        "/d",
        "/s",
        "/c",
        $Command
      ) `
      -WorkingDirectory $root `
      -RedirectStandardOutput $out `
      -RedirectStandardError $err `
      -NoNewWindow `
      -Wait `
      -PassThru

  $stdout =
    if (Test-Path $out) {
      Get-Content $out -Raw
    }
    else {
      ""
    }

  $stderr =
    if (Test-Path $err) {
      Get-Content $err -Raw
    }
    else {
      ""
    }

  if ($stdout) {
    Write-Host $stdout
    Add-Content $log $stdout -Encoding UTF8
  }

  if ($stderr) {
    Write-Host $stderr
    Add-Content $log $stderr -Encoding UTF8
  }

  if (
    $process.ExitCode -ne 0
  ) {
    $diag =
      Join-Path `
        $logs `
        "FAILED-phase008c-$stamp-$($Name.Replace(' ','-')).log"

    WriteText `
      $diag `
      "COMMAND:`n$Command`n`nEXIT CODE:`n$($process.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diag"
  }

  Remove-Item `
    $out,$err `
    -Force `
    -ErrorAction SilentlyContinue

  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content `
    $log `
    "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" `
    -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 008C: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008C" -ForegroundColor Cyan
Write-Host "Learner Journey Orchestration" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ============================================================
# 1. Journey model
# ============================================================

WriteText (Join-Path $journeyRoot "learnerJourney.ts") @'
export type LearnerJourneyView =
  | "home"
  | "explore"
  | "activity";

export interface LearnerJourneyState {
  view:
    LearnerJourneyView;

  activeActivityId:
    string | null;

  previousView:
    Exclude<
      LearnerJourneyView,
      "activity"
    > | null;
}

export type LearnerJourneyAction =
  | {
      type:
        "GO_HOME";
    }
  | {
      type:
        "GO_EXPLORE";
    }
  | {
      type:
        "OPEN_ACTIVITY";

      activityId:
        string;

      from:
        "home" |
        "explore";
    }
  | {
      type:
        "CLOSE_ACTIVITY";
    };

export const initialLearnerJourneyState:
  LearnerJourneyState = {
    view:
      "home",

    activeActivityId:
      null,

    previousView:
      null
  };

export function learnerJourneyReducer(
  state:
    LearnerJourneyState,

  action:
    LearnerJourneyAction
):
  LearnerJourneyState {
  switch (
    action.type
  ) {
    case "GO_HOME":
      return {
        view:
          "home",

        activeActivityId:
          null,

        previousView:
          null
      };

    case "GO_EXPLORE":
      return {
        view:
          "explore",

        activeActivityId:
          null,

        previousView:
          null
      };

    case "OPEN_ACTIVITY":
      return {
        view:
          "activity",

        activeActivityId:
          action.activityId,

        previousView:
          action.from
      };

    case "CLOSE_ACTIVITY":
      return {
        view:
          state.previousView ??
          "home",

        activeActivityId:
          null,

        previousView:
          null
      };

    default:
      return state;
  }
}
'@

# ============================================================
# 2. Hook/controller
# ============================================================

WriteText (Join-Path $journeyRoot "useLearnerJourney.ts") @'
import {
  useCallback,
  useReducer
} from "react";

import {
  initialLearnerJourneyState,
  learnerJourneyReducer
} from "./learnerJourney";

export function useLearnerJourney() {
  const [
    state,
    dispatch
  ] =
    useReducer(
      learnerJourneyReducer,
      initialLearnerJourneyState
    );

  const goHome =
    useCallback(
      () => {
        dispatch({
          type:
            "GO_HOME"
        });
      },
      []
    );

  const goExplore =
    useCallback(
      () => {
        dispatch({
          type:
            "GO_EXPLORE"
        });
      },
      []
    );

  const openActivity =
    useCallback(
      (
        activityId:
          string,

        from:
          "home" |
          "explore"
      ) => {
        dispatch({
          type:
            "OPEN_ACTIVITY",

          activityId,

          from
        });
      },
      []
    );

  const closeActivity =
    useCallback(
      () => {
        dispatch({
          type:
            "CLOSE_ACTIVITY"
        });
      },
      []
    );

  return {
    state,
    goHome,
    goExplore,
    openActivity,
    closeActivity
  };
}
'@

# ============================================================
# 3. Explore placeholder using existing product language.
# ============================================================

WriteText (Join-Path $journeyRoot "LearnerExplore.tsx") @'
export interface LearnerExploreProps {
  onBack:
    () => void;

  onOpenActivity:
    (
      activityId:
        string
    ) => void;
}

export function LearnerExplore({
  onBack,
  onOpenActivity
}: LearnerExploreProps) {
  return (
    <section className="rounded-3xl bg-white p-6 shadow-sm ring-1 ring-slate-100 sm:p-8">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-sm font-bold uppercase tracking-wide text-emerald-700">
            Teroka
          </p>

          <h2 className="mt-2 text-2xl font-black text-slate-900">
            Pilih aktiviti
          </h2>
        </div>

        <button
          type="button"
          onClick={onBack}
          className="min-h-14 rounded-2xl border-2 border-slate-200 bg-white px-5 py-3 text-base font-extrabold text-slate-700 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-slate-200"
        >
          Kembali
        </button>
      </div>

      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        <button
          type="button"
          onClick={
            () =>
              onOpenActivity(
                "warna-merah-001"
              )
          }
          className="min-h-20 rounded-2xl border-2 border-rose-200 bg-rose-50 p-5 text-left focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-rose-200"
        >
          <span className="block text-lg font-black text-slate-900">
            Kenal warna merah
          </span>

          <span className="mt-1 block text-sm font-medium text-slate-600">
            Aktiviti ringkas mengenal warna.
          </span>
        </button>

        <button
          type="button"
          onClick={
            () =>
              onOpenActivity(
                "warna-bunga-raya-001"
              )
          }
          className="min-h-20 rounded-2xl border-2 border-amber-200 bg-amber-50 p-5 text-left focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-amber-200"
        >
          <span className="block text-lg font-black text-slate-900">
            Warna bunga raya
          </span>

          <span className="mt-1 block text-sm font-medium text-slate-600">
            Kenal warna melalui bunga raya.
          </span>
        </button>
      </div>
    </section>
  );
}
'@

# ============================================================
# 4. Activity bridge boundary.
#    Actual ActivityPlayer props are intentionally not guessed here.
# ============================================================

WriteText (Join-Path $journeyRoot "LearnerActivityBridge.tsx") @'
export interface LearnerActivityBridgeProps {
  activityId:
    string;

  onClose:
    () => void;
}

export function LearnerActivityBridge({
  activityId,
  onClose
}: LearnerActivityBridgeProps) {
  return (
    <section className="rounded-3xl bg-white p-6 shadow-sm ring-1 ring-slate-100 sm:p-8">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-sm font-bold uppercase tracking-wide text-amber-700">
            Aktiviti
          </p>

          <h2 className="mt-2 text-2xl font-black text-slate-900">
            {activityId}
          </h2>
        </div>

        <button
          type="button"
          onClick={onClose}
          className="min-h-14 rounded-2xl border-2 border-slate-200 bg-white px-5 py-3 text-base font-extrabold text-slate-700 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-slate-200"
        >
          Keluar aktiviti
        </button>
      </div>

      <p className="mt-5 max-w-2xl text-base leading-7 text-slate-600">
        Sambungan kepada ActivityPlayer akan dibuat melalui adapter yang menggunakan kontrak runtime sebenar, bukan melalui patch andaian.
      </p>
    </section>
  );
}
'@

# ============================================================
# 5. Journey screen
# ============================================================

WriteText (Join-Path $journeyRoot "LearnerJourney.tsx") @'
import {
  LearnerHome,
  LearnerRuntimeShell
} from "../shell";

import {
  LearnerActivityBridge
} from "./LearnerActivityBridge";

import {
  LearnerExplore
} from "./LearnerExplore";

import {
  useLearnerJourney
} from "./useLearnerJourney";

export function LearnerJourney() {
  const {
    state,
    goHome,
    goExplore,
    openActivity,
    closeActivity
  } =
    useLearnerJourney();

  return (
    <LearnerRuntimeShell
      progressPercent={0}
    >
      {
        state.view ===
        "home"
          ? (
              <LearnerHome
                onContinue={
                  () =>
                    openActivity(
                      "warna-merah-001",
                      "home"
                    )
                }
                onExplore={
                  goExplore
                }
              />
            )
          : null
      }

      {
        state.view ===
        "explore"
          ? (
              <LearnerExplore
                onBack={
                  goHome
                }
                onOpenActivity={
                  activityId =>
                    openActivity(
                      activityId,
                      "explore"
                    )
                }
              />
            )
          : null
      }

      {
        state.view ===
          "activity" &&
        state.activeActivityId
          ? (
              <LearnerActivityBridge
                activityId={
                  state.activeActivityId
                }
                onClose={
                  closeActivity
                }
              />
            )
          : null
      }
    </LearnerRuntimeShell>
  );
}
'@

WriteText (Join-Path $journeyRoot "index.ts") @'
export {
  LearnerJourney
} from "./LearnerJourney";

export {
  LearnerExplore,
  type LearnerExploreProps
} from "./LearnerExplore";

export {
  LearnerActivityBridge,
  type LearnerActivityBridgeProps
} from "./LearnerActivityBridge";

export {
  initialLearnerJourneyState,
  learnerJourneyReducer,
  type LearnerJourneyAction,
  type LearnerJourneyState,
  type LearnerJourneyView
} from "./learnerJourney";

export {
  useLearnerJourney
} from "./useLearnerJourney";
'@

# ============================================================
# 6. Reducer tests: no additional browser testing dependency.
# ============================================================

WriteText (Join-Path $journeyRoot "learnerJourney.test.ts") @'
import {
  describe,
  expect,
  it
} from "vitest";

import {
  initialLearnerJourneyState,
  learnerJourneyReducer
} from "./learnerJourney";

describe(
  "learnerJourneyReducer",
  () => {
    it(
      "opens an activity from home and returns home",
      () => {
        const opened =
          learnerJourneyReducer(
            initialLearnerJourneyState,
            {
              type:
                "OPEN_ACTIVITY",

              activityId:
                "warna-merah-001",

              from:
                "home"
            }
          );

        expect(
          opened
        ).toEqual({
          view:
            "activity",

          activeActivityId:
            "warna-merah-001",

          previousView:
            "home"
        });

        expect(
          learnerJourneyReducer(
            opened,
            {
              type:
                "CLOSE_ACTIVITY"
            }
          )
        ).toEqual(
          initialLearnerJourneyState
        );
      }
    );

    it(
      "returns to explore after an activity opened from explore",
      () => {
        const explore =
          learnerJourneyReducer(
            initialLearnerJourneyState,
            {
              type:
                "GO_EXPLORE"
            }
          );

        const opened =
          learnerJourneyReducer(
            explore,
            {
              type:
                "OPEN_ACTIVITY",

              activityId:
                "warna-bunga-raya-001",

              from:
                "explore"
            }
          );

        const closed =
          learnerJourneyReducer(
            opened,
            {
              type:
                "CLOSE_ACTIVITY"
            }
          );

        expect(
          closed.view
        ).toBe(
          "explore"
        );

        expect(
          closed.activeActivityId
        ).toBeNull();
      }
    );
  }
);
'@

# ============================================================
# 7. Storybook journey review
# ============================================================

WriteText (Join-Path $root "apps\ui-storybook\stories\LearnerJourney.stories.tsx") @'
import {
  LearnerJourney
} from "../../learner-web/src/journey";

export default {
  title:
    "Learner/Journey"
};

export function Default() {
  return (
    <LearnerJourney />
  );
}
'@

# ============================================================
# 8. Validate. No blind ActivityPlayer integration.
# ============================================================

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
  Run "Stage Phase 008C" "git add apps/learner-web/src/journey apps/ui-storybook/stories/LearnerJourney.stories.tsx"
  Run "Commit Phase 008C" 'git commit -m "feat: add learner journey orchestration"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008C: PASS - JOURNEY READY" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Manual review:" -ForegroundColor Cyan
Write-Host "  pnpm storybook" -ForegroundColor White
Write-Host "Open: Learner -> Journey -> Default" -ForegroundColor White
Write-Host ""
Write-Host "Next: inspect the real ActivityPlayer contract and replace LearnerActivityBridge with a typed adapter." -ForegroundColor Cyan
