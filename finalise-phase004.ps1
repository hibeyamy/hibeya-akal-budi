param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$playerPath = Join-Path $repoRoot "apps\learner-web\src\features\play\ActivityPlayer.tsx"
$packagePath = Join-Path $repoRoot "apps\learner-web\package.json"
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
  $stdout = Join-Path $logsRoot "native-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "native-$timestamp-err.log"

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
    $diagnostic = Join-Path $logsRoot "FAILED-$timestamp-$($Name.Replace(' ','-')).log"

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


if (-not (Test-Path $playerPath)) {
  throw "ActivityPlayer.tsx not found."
}

if (-not (Test-Path $packagePath)) {
  throw "learner-web package.json not found."
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - FINAL PHASE 004 INTEGRATION" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan


Write-Step "Backing up current files"
Backup-File $playerPath
Backup-File $packagePath


Write-Step "Replacing ActivityPlayer.tsx as a whole"

$player = @'
import {
  useEffect,
  useMemo,
  useState
} from "react";

import {
  getAsset
} from "@akal-budi/assets";

import {
  getGameMechanic
} from "@akal-budi/game-mechanics";

import {
  addLocalAnswer,
  completeLocalSession,
  createLocalSession,
  getCachedLearnerRuntimeProfile,
  getLatestIncompleteSession,
  getLearnerDevice,
  getLearnerJourneyState,
  processPendingSessions,
  recordCompletedJourneyActivity,
  saveLearnerRuntimeProfile,
  type StoredSession
} from "@akal-budi/offline";

import {
  useNetworkStatus
} from "../../hooks/useNetworkStatus";

import {
  getLearnerRuntimeProfile,
  type LearnerAgeBand
} from "../../services/deviceActivationService";

import {
  localSyncProvider
} from "../../services/localSyncProvider";

import {
  resolveRuntimeActivity
} from "./resolvePlayableActivity";

import {
  selectLearnerActivity
} from "./selectLearnerActivity";


function createSessionId():
  string {
  return crypto.randomUUID();
}


type ReadyPlayerState = {
  status:
    "ready";

  activityId:
    string;

  ageBand:
    LearnerAgeBand;

  offlineProfile:
    boolean;
};


type PlayerState =
  | {
      status:
        "loading";
    }
  | ReadyPlayerState
  | {
      status:
        "no-content";

      ageBand:
        LearnerAgeBand;
    }
  | {
      status:
        "error";

      message:
        string;
    };


export function ActivityPlayer() {
  const network =
    useNetworkStatus();

  const [
    playerState,
    setPlayerState
  ] =
    useState<PlayerState>({
      status:
        "loading"
    });


  useEffect(
    () => {
      void initialiseLearner();
    },
    [
      network.online
    ]
  );


  async function initialiseLearner() {
    setPlayerState({
      status:
        "loading"
    });


    const device =
      await getLearnerDevice();


    if (!device) {
      setPlayerState({
        status:
          "error",

        message:
          "Peranti pembelajaran belum diaktifkan."
      });

      return;
    }


    if (
      network.online
    ) {
      try {
        const profile =
          await getLearnerRuntimeProfile(
            device.deviceId,
            device.deviceToken
          );


        if (
          profile.childId !==
          device.childId
        ) {
          setPlayerState({
            status:
              "error",

            message:
              "Identiti profil pembelajaran tidak sepadan."
          });

          return;
        }


        await saveLearnerRuntimeProfile({
          childId:
            profile.childId,

          ageBand:
            profile.ageBand,

          preferredLanguage:
            profile.preferredLanguage,

          validatedAt:
            Date.now()
        });


        await selectActivityForProfile(
          profile.ageBand,
          false
        );

        return;

      } catch {
        /*
         * When the device is online, do not silently fall back
         * to the cached profile. The server may have rejected a
         * revoked or otherwise invalid learner device.
         */
        setPlayerState({
          status:
            "error",

          message:
            "Peranti pembelajaran tidak dapat disahkan. Cuba semula apabila sambungan stabil."
        });

        return;
      }
    }


    const cachedProfile =
      await getCachedLearnerRuntimeProfile();


    if (!cachedProfile) {
      setPlayerState({
        status:
          "error",

        message:
          "Profil pembelajaran belum tersedia untuk penggunaan luar talian."
      });

      return;
    }


    if (
      cachedProfile.childId !==
      device.childId
    ) {
      setPlayerState({
        status:
          "error",

        message:
          "Profil luar talian tidak sepadan dengan peranti ini."
      });

      return;
    }


    await selectActivityForProfile(
      cachedProfile.ageBand,
      true
    );
  }


  async function selectActivityForProfile(
    ageBand:
      LearnerAgeBand,

    offlineProfile:
      boolean
  ) {
    const journey =
      await getLearnerJourneyState();


    const selected =
      selectLearnerActivity({
        ageBand,

        lastCompletedActivityId:
          journey.lastCompletedActivityId
      });


    if (!selected) {
      setPlayerState({
        status:
          "no-content",

        ageBand
      });

      return;
    }


    setPlayerState({
      status:
        "ready",

      activityId:
        selected.id,

      ageBand,

      offlineProfile
    });
  }


  async function continueJourney(
    state:
      ReadyPlayerState
  ) {
    await selectActivityForProfile(
      state.ageBand,
      state.offlineProfile
    );
  }


  if (
    playerState.status ===
    "loading"
  ) {
    return (
      <LearnerMessage
        title="Akal Budi"
        message="Memilih aktiviti yang sesuai..."
      />
    );
  }


  if (
    playerState.status ===
    "error"
  ) {
    return (
      <LearnerMessage
        title="Aktiviti belum dapat dimulakan"
        message={
          playerState.message
        }
      />
    );
  }


  if (
    playerState.status ===
    "no-content"
  ) {
    return (
      <LearnerMessage
        title="Aktiviti sedang disediakan"
        message={
          `Belum ada aktiviti yang diluluskan untuk umur ${playerState.ageBand} dalam versi ini.`
        }
      />
    );
  }


  const runtimeActivity =
    resolveRuntimeActivity(
      playerState.activityId
    );


  if (!runtimeActivity) {
    return (
      <LearnerMessage
        title="Aktiviti belum tersedia"
        message="Kandungan aktiviti tidak dapat dimuatkan."
      />
    );
  }


  return (
    <ResolvedActivityPlayer
      key={
        runtimeActivity
          .catalogue
          .id
      }
      runtimeActivity={
        runtimeActivity
      }
      network={
        network
      }
      offlineProfile={
        playerState
          .offlineProfile
      }
      onContinue={
        () =>
          void continueJourney(
            playerState
          )
      }
    />
  );
}


function LearnerMessage({
  title,
  message
}: {
  title: string;

  message: string;
}) {
  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col items-center justify-center px-4 py-10">
      <section className="w-full rounded-[2rem] bg-white p-6 text-center shadow-sm sm:p-8">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
          HIBEYA
        </p>

        <h1 className="mt-2 text-3xl font-bold text-slate-900">
          {title}
        </h1>

        <p className="mt-5 leading-7 text-slate-600">
          {message}
        </p>
      </section>
    </main>
  );
}


interface ResolvedActivityPlayerProps {
  runtimeActivity:
    NonNullable<
      ReturnType<
        typeof resolveRuntimeActivity
      >
    >;

  network:
    ReturnType<
      typeof useNetworkStatus
    >;

  offlineProfile:
    boolean;

  onContinue:
    () => void;
}


function ResolvedActivityPlayer({
  runtimeActivity,
  network,
  offlineProfile,
  onContinue
}: ResolvedActivityPlayerProps) {
  const activity =
    runtimeActivity
      .implementation
      .activity;

  const catalogue =
    runtimeActivity
      .catalogue;

  const mechanic =
    useMemo(
      () =>
        getGameMechanic(
          activity.mechanic
        ),
      [
        activity.mechanic
      ]
    );

  const [
    context
  ] =
    useState(
      () =>
        mechanic.start(
          activity
        )
    );

  const [
    sessionId,
    setSessionId
  ] =
    useState<string>(
      () =>
        createSessionId()
    );

  const [
    answers,
    setAnswers
  ] =
    useState<
      ReturnType<
        typeof mechanic.submitAnswer
      >[]
    >([]);

  const [
    selectedId,
    setSelectedId
  ] =
    useState<
      string | null
    >(null);

  const [
    feedback,
    setFeedback
  ] =
    useState<
      string | null
    >(null);

  const [
    sessionInitialised,
    setSessionInitialised
  ] =
    useState(false);

  const [
    recoverySession,
    setRecoverySession
  ] =
    useState<
      StoredSession | null
    >(null);

  const [
    syncMessage,
    setSyncMessage
  ] =
    useState<
      string | null
    >(null);

  const [
    completed,
    setCompleted
  ] =
    useState(false);


  useEffect(
    () => {
      void getLatestIncompleteSession()
        .then(
          (
            session
          ) => {
            if (
              session &&
              session.activityId ===
                activity.id
            ) {
              setRecoverySession(
                session
              );
            }
          }
        );
    },
    [
      activity.id
    ]
  );


  useEffect(
    () => {
      if (
        !network.online
      ) {
        return;
      }


      void processPendingSessions(
        localSyncProvider
      ).then(
        (
          result
        ) => {
          if (
            result.attempted >
            0
          ) {
            setSyncMessage(
              `${result.succeeded} aktiviti diselaraskan`
            );
          }
        }
      );
    },
    [
      network.online
    ]
  );


  async function ensureSession() {
    if (
      sessionInitialised
    ) {
      return;
    }


    await createLocalSession({
      id:
        sessionId,

      activityId:
        activity.id,

      activityVersion:
        activity.version,

      startedAt:
        context.startedAt
    });


    setSessionInitialised(
      true
    );
  }


  async function handleAnswer(
    optionId: string
  ) {
    if (
      completed
    ) {
      return;
    }


    await ensureSession();


    const answer =
      mechanic.submitAnswer(
        context,
        optionId
      );


    await addLocalAnswer(
      sessionId,
      answer
    );


    const nextAnswers = [
      ...answers,
      answer
    ];


    setAnswers(
      nextAnswers
    );

    setSelectedId(
      optionId
    );


    if (
      answer.correct
    ) {
      setFeedback(
        "Betul! Bagus."
      );


      const result =
        mechanic.complete(
          context,
          nextAnswers
        );


      await completeLocalSession(
        sessionId,
        result
      );


      await recordCompletedJourneyActivity(
        activity.id
      );


      setRecoverySession(
        null
      );

      setCompleted(
        true
      );


      if (
        network.online
      ) {
        const syncResult =
          await processPendingSessions(
            localSyncProvider
          );


        if (
          syncResult.attempted >
          0
        ) {
          setSyncMessage(
            `${syncResult.succeeded} aktiviti diselaraskan`
          );
        }
      }

    } else {
      setFeedback(
        "Cuba lagi."
      );
    }
  }


  function resumePreviousSession() {
    if (
      !recoverySession
    ) {
      return;
    }


    setSessionId(
      recoverySession.id
    );

    setAnswers(
      recoverySession.answers
    );

    setSessionInitialised(
      true
    );

    setRecoverySession(
      null
    );


    const lastAnswer =
      recoverySession
        .answers
        .at(-1);


    if (
      lastAnswer
    ) {
      setSelectedId(
        lastAnswer.optionId
      );

      setFeedback(
        lastAnswer.correct
          ? "Betul! Bagus."
          : "Sambung semula."
      );
    }
  }


  function startNewSession() {
    setRecoverySession(
      null
    );

    setSessionId(
      createSessionId()
    );

    setAnswers([]);

    setSelectedId(
      null
    );

    setFeedback(
      null
    );

    setSessionInitialised(
      false
    );

    setCompleted(
      false
    );
  }


  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col px-4 py-6 sm:px-6 sm:py-10">
      <header className="mb-8">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
          HIBEYA
        </p>

        <h1 className="mt-1 text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">
          Akal Budi
        </h1>

        <p className="mt-1 text-sm text-slate-600 sm:text-base">
          Membina Akal. Menyemai Budi.
        </p>


        {!network.online && (
          <div className="mt-3 inline-flex rounded-full bg-amber-100 px-3 py-1 text-sm font-semibold text-amber-800">
            Mod luar talian
          </div>
        )}


        {offlineProfile && (
          <div className="mt-3 inline-flex rounded-full bg-slate-100 px-3 py-1 text-sm font-semibold text-slate-700">
            Profil umur disimpan pada peranti
          </div>
        )}


        {syncMessage &&
          network.online && (
            <div className="mt-3 inline-flex rounded-full bg-emerald-100 px-3 py-1 text-sm font-semibold text-emerald-800">
              {syncMessage}
            </div>
          )}
      </header>


      {recoverySession && (
        <section className="mb-5 rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
          <p className="font-semibold text-slate-900">
            Aktiviti sebelumnya belum selesai.
          </p>

          <p className="mt-1 text-sm text-slate-600">
            Sambung dari tempat terakhir atau mula semula.
          </p>

          <div className="mt-4 flex flex-col gap-3 sm:flex-row">
            <button
              type="button"
              onClick={
                resumePreviousSession
              }
              className="rounded-2xl bg-slate-900 px-5 py-3 font-semibold text-white"
            >
              Sambung
            </button>

            <button
              type="button"
              onClick={
                startNewSession
              }
              className="rounded-2xl border border-slate-300 bg-white px-5 py-3 font-semibold text-slate-700"
            >
              Mula semula
            </button>
          </div>
        </section>
      )}


      <section className="rounded-[2rem] bg-white p-5 shadow-sm sm:p-8">
        <div className="mb-7 text-center">
          <p className="text-sm font-semibold text-amber-700">
            {
              catalogue
                .blueprint
                .titleMs
            }
          </p>

          <h2 className="mt-2 text-2xl font-bold text-slate-900 sm:text-3xl">
            {
              activity
                .title
                .ms
            }
          </h2>

          <p className="mt-3 text-lg text-slate-700 sm:text-xl">
            {
              activity
                .instruction
                .ms
            }
          </p>
        </div>


        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          {
            activity
              .options
              .map(
                (
                  option
                ) => {
                  const asset =
                    getAsset(
                      option.asset
                    );

                  const isSelected =
                    selectedId ===
                    option.id;


                  return (
                    <button
                      key={
                        option.id
                      }
                      type="button"
                      disabled={
                        completed
                      }
                      onClick={
                        () =>
                          void handleAnswer(
                            option.id
                          )
                      }
                      aria-label={
                        asset
                          .alt
                          .ms
                      }
                      className={[
                        "flex min-h-40 touch-manipulation flex-col items-center justify-center",
                        "rounded-3xl border-2 px-4 py-6",
                        "transition duration-150 active:scale-95",
                        "focus:outline-none focus:ring-4 focus:ring-amber-200",
                        completed
                          ? "cursor-default opacity-80"
                          : "",
                        isSelected
                          ? "border-amber-500 bg-amber-50"
                          : "border-slate-200 bg-slate-50 hover:border-amber-300"
                      ].join(
                        " "
                      )}
                    >
                      {
                        asset.type ===
                        "image"
                          ? (
                            <img
                              src={
                                asset.value
                              }
                              alt=""
                              aria-hidden="true"
                              draggable={
                                false
                              }
                              className="h-40 w-40 select-none object-contain sm:h-44 sm:w-44"
                            />
                          )
                          : (
                            <span
                              aria-hidden="true"
                              className="text-7xl sm:text-8xl"
                            >
                              {
                                asset.value
                              }
                            </span>
                          )
                      }


                      <span className="mt-4 text-base font-semibold text-slate-700">
                        {
                          asset
                            .alt
                            .ms
                        }
                      </span>
                    </button>
                  );
                }
              )
          }
        </div>


        <div
          className="mt-7 min-h-10 text-center text-xl font-bold text-slate-800"
          aria-live="polite"
        >
          {feedback}
        </div>


        {completed && (
          <section className="mt-4 rounded-3xl bg-emerald-50 p-5 text-center">
            <p className="font-semibold text-emerald-900">
              Aktiviti selesai.
            </p>

            <p className="mt-1 text-sm leading-6 text-emerald-800">
              Bagus. Boleh berhenti di sini atau pilih aktiviti seterusnya.
            </p>

            <button
              type="button"
              onClick={
                onContinue
              }
              className="mt-4 rounded-2xl bg-slate-900 px-5 py-3 font-semibold text-white"
            >
              Aktiviti seterusnya
            </button>
          </section>
        )}
      </section>
    </main>
  );
}

'@

Write-Utf8NoBom `
  -Path $playerPath `
  -Content $player


Write-Step "Enabling the learner-web Vitest suite"

$packageJson =
  Get-Content $packagePath -Raw

if (
  $packageJson -match
  '"test"\s*:\s*"echo \\"tests pending\\""'
) {
  $packageJson =
    [regex]::Replace(
      $packageJson,
      '"test"\s*:\s*"echo \\"tests pending\\""',
      '"test": "vitest run"'
    )
}
elseif (
  $packageJson -notmatch
  '"test"\s*:'
) {
  throw "learner-web package.json has no test script. Stopped rather than rewriting package.json structure."
}

Write-Utf8NoBom `
  -Path $packagePath `
  -Content $packageJson


Write-Step "Verifying required Phase 004 APIs exist"

$requiredFiles = @(
  "apps\learner-web\src\features\play\selectLearnerActivity.ts",
  "packages\offline\src\learnerRuntimeProfile.repository.ts",
  "packages\offline\src\learningJourney.repository.ts",
  "supabase\migrations\20260820043100_learner_runtime_profile.sql"
)

foreach ($relative in $requiredFiles) {
  $full = Join-Path $repoRoot $relative

  if (-not (Test-Path $full)) {
    throw "Missing required Phase 004 file: $relative"
  }
}


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
else {
  Write-Host ""
  Write-Host "Security regression skipped: .env.security.local not found." -ForegroundColor Yellow
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
    -Command 'git commit -m "feat: complete age-aware offline learner journey"'
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "FINAL PHASE 004 INTEGRATION: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "The database migration is still dry-run only." -ForegroundColor Yellow
Write-Host "Do not push it until the learner flow is verified in the browser." -ForegroundColor Yellow
