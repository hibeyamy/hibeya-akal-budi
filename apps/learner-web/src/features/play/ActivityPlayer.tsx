import {
  useEffect,
  useMemo,
  useRef,
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
  deleteLocalSession,
  getCachedLearnerRuntimeProfile,
  getLatestIncompleteSessionForActivity,
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
  getLearnerSkillProgress,
  recordSessionSkillMastery
} from "../../services/skillMasteryService";

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

  childId:
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
          profile.childId,
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
      cachedProfile.childId,
      cachedProfile.ageBand,
      true
    );
  }


  async function selectActivityForProfile(
    childId:
      string,

    ageBand:
      LearnerAgeBand,

    offlineProfile:
      boolean
  ) {
    const [
      journey,
      skillProgress
    ] =
      await Promise.all([
        getLearnerJourneyState(),
        getLearnerSkillProgress()
      ]);

    const masteredSkillIds =
      skillProgress
        .filter(
          skill =>
            skill.level ===
              "mastered"
        )
        .map(
          skill =>
            skill.skillId
        );


    const selected =
      selectLearnerActivity({
        childId,

        ageBand,

        lastCompletedActivityId:
          journey.lastCompletedActivityId,

        completedActivityIds:
          journey.completedActivityIds,

        masteredSkillIds,

        skillProgress
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

      childId,

      ageBand,

      offlineProfile
    });
  }


  async function continueJourney(
    state:
      ReadyPlayerState
  ) {
    await selectActivityForProfile(
      state.childId,
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


export interface ActivityPlayerAdapterProps {
  activityId: string;
  onComplete?: () => void;
  onExit: () => void;
}

export function ActivityPlayerAdapter({
  activityId,
  onComplete,
  onExit
}: ActivityPlayerAdapterProps) {
  const network = useNetworkStatus();
  const runtimeActivity = resolveRuntimeActivity(activityId);

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
      key={runtimeActivity.catalogue.id}
      runtimeActivity={runtimeActivity}
      network={network}
      offlineProfile={false}
      onContinue={onExit}
      onComplete={onComplete}
      onExit={onExit}
      explicitJourneyMode={true}
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

  onComplete?:
    () => void;

  onExit?:
    () => void;

  explicitJourneyMode?:
    boolean;
}


function ResolvedActivityPlayer({
  runtimeActivity,
  network,
  offlineProfile,
  onContinue,
  onComplete,
  onExit,
  explicitJourneyMode = false
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
    sessionStartedAt,
    setSessionStartedAt
  ] =
    useState<number>(
      context.startedAt
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
    recoveryChecked,
    setRecoveryChecked
  ] =
    useState(false);

  const sessionCreationPromise =
    useRef<Promise<void> | null>(
      null
    );

  const answerInFlight =
    useRef(false);

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
      setRecoveryChecked(
        false
      );

      void getLatestIncompleteSessionForActivity(
        activity.id,
        activity.version
      )
        .then(
          (
            session
          ) => {
            setRecoverySession(
              session ?? null
            );
            setRecoveryChecked(
              true
            );
          }
        )
        .catch(
          () => {
            // Persisted recovery data is optional. If it cannot be
            // read safely, start from a clean in-memory activity.
            setRecoverySession(
              null
            );
            setRecoveryChecked(
              true
            );
          }
        );
    },
    [
      activity.id,
      activity.version
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

    if (
      sessionCreationPromise.current
    ) {
      await sessionCreationPromise.current;
      return;
    }

    const creation =
      createLocalSession({
        id:
          sessionId,

        activityId:
          activity.id,

        activityVersion:
          activity.version,

        startedAt:
          sessionStartedAt
      }).then(
        () => {
          setSessionInitialised(
            true
          );
        }
      );

    sessionCreationPromise.current =
      creation;

    try {
      await creation;
    } finally {
      sessionCreationPromise.current =
        null;
    }
  }


  async function handleAnswer(
    optionId: string
  ) {
    if (
      completed ||
      recoverySession ||
      !recoveryChecked ||
      answerInFlight.current
    ) {
      return;
    }

    answerInFlight.current =
      true;

    try {
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
          {
            ...context,
            startedAt:
              sessionStartedAt
          },
          nextAnswers
        );


      await completeLocalSession(
        sessionId,
        result
      );


      await recordSessionSkillMastery({
        sessionId,
        result,
        skillMappings:
          catalogue.skillMappings
      });


      await recordCompletedJourneyActivity(
        activity.id,
        sessionId
      );


      onComplete?.();


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
    } finally {
      answerInFlight.current =
        false;
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

    sessionCreationPromise.current =
      null;

    setSessionInitialised(
      true
    );

    setSessionStartedAt(
      recoverySession.startedAt
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


  async function startNewSession() {
    const previousSession =
      recoverySession;

    if (previousSession) {
      await deleteLocalSession(
        previousSession.id
      );
    }

    setRecoverySession(
      null
    );

    setSessionId(
      createSessionId()
    );

    setSessionStartedAt(
      Date.now()
    );

    setAnswers([]);

    setSelectedId(
      null
    );

    setFeedback(
      null
    );

    sessionCreationPromise.current =
      null;

    setSessionInitialised(
      false
    );

    setCompleted(
      false
    );
  }


  return (
    <section
      className="mx-auto flex min-h-screen max-w-3xl flex-col px-4 py-6 sm:px-6 sm:py-10"
      data-testid="activity-player"
      data-activity-id={activity.id}
      data-activity-state={
        completed
          ? "completed"
          : answers.length > 0
            ? "retry"
            : "idle"
      }
      data-answer-count={answers.length}
    >
      <header className="mb-8">
        {explicitJourneyMode && onExit && (
          <button
            type="button"
            onClick={onExit}
            className="mb-5 min-h-14 rounded-2xl border-2 border-slate-200 bg-white px-5 py-3 font-extrabold text-slate-700 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-slate-200"
          >
            Keluar aktiviti
          </button>
        )}

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
                () =>
                  void startNewSession()
              }
              className="rounded-2xl border border-slate-300 bg-white px-5 py-3 font-semibold text-slate-700"
            >
              Mula semula
            </button>
          </div>
        </section>
      )}


      <section
        className="rounded-[2rem] border border-amber-100 bg-white p-5 shadow-sm sm:p-8"
        data-testid="learner-activity-card"
      >
        <div className="mb-7 text-center">
          <span
            aria-hidden="true"
            className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-amber-100 text-2xl"
          >
            ★
          </span>
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

          <p className="mx-auto mt-3 max-w-xl text-lg font-semibold leading-relaxed text-slate-700 sm:text-xl">
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

                  const selectedAnswer =
                    isSelected
                      ? answers.at(-1)
                      : null;

                  const selectedState =
                    selectedAnswer
                      ? (
                          selectedAnswer.correct
                            ? "correct"
                            : "incorrect"
                        )
                      : (
                          isSelected
                            ? "selected"
                            : "idle"
                        );


                  return (
                    <button
                      key={
                        option.id
                      }
                      type="button"
                      data-testid="learner-choice"
                      data-option-id={
                        option.id
                      }
                      data-asset-id={
                        option.asset
                      }
                      data-visual-state={
                        selectedState
                      }
                      disabled={
                        completed ||
                        !recoveryChecked ||
                        Boolean(
                          recoverySession
                        )
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
                      aria-pressed={
                        isSelected
                      }
                      className={[
                        "relative flex min-h-40 touch-manipulation flex-col items-center justify-center",
                        "rounded-3xl border-2 px-4 py-6 shadow-sm",
                        "transition duration-150 active:scale-[0.98] motion-reduce:transition-none motion-reduce:active:scale-100",
                        "focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-amber-200",
                        completed
                          ? "cursor-default opacity-80"
                          : "",
                        selectedState === "correct"
                          ? "border-emerald-500 bg-emerald-50 shadow-md"
                          : selectedState === "incorrect"
                            ? "border-rose-500 bg-rose-50 shadow-md"
                            : selectedState === "selected"
                              ? "border-amber-500 bg-amber-50 shadow-md"
                              : "border-slate-200 bg-slate-50 hover:border-amber-300 hover:bg-amber-50/40"
                      ].join(
                        " "
                      )}
                    >
                      {selectedState !== "idle" && (
                        <span
                          aria-hidden="true"
                          data-testid="learner-choice-state-icon"
                          className={[
                            "absolute right-3 top-3 flex h-10 w-10 items-center justify-center rounded-full border-2 bg-white text-xl font-black shadow-sm",
                            selectedState === "correct"
                              ? "border-emerald-500 text-emerald-700"
                              : selectedState === "incorrect"
                                ? "border-rose-500 text-rose-700"
                                : "border-amber-500 text-amber-700"
                          ].join(" ")}
                        >
                          {
                            selectedState === "correct"
                              ? "✓"
                              : selectedState === "incorrect"
                                ? "×"
                                : "●"
                          }
                        </span>
                      )}

                      <span
                        className="flex h-40 w-40 items-center justify-center overflow-hidden sm:h-44 sm:w-44"
                        data-testid="learner-choice-visual"
                      >
                        {
                          asset.type ===
                          "image"
                            ? (
                              <img
                                src={asset.value}
                                alt=""
                                aria-hidden="true"
                                draggable={false}
                                data-production-asset={option.asset}
                                className="h-full w-full select-none object-contain"
                              />
                            )
                            : asset.type ===
                              "quantity"
                              ? (
                                <span
                                  aria-hidden="true"
                                  data-quantity-asset={option.asset}
                                  className="grid grid-cols-2 place-items-center gap-1"
                                >
                                  {Array.from({ length: asset.count ?? 0 }).map((_, index) => {
                                    const item = getAsset(asset.itemAsset ?? "");
                                    return item.type === "image"
                                      ? <img key={index} src={item.value} alt="" draggable={false} className="h-16 w-16 select-none object-contain sm:h-20 sm:w-20" />
                                      : <span key={index} className="text-5xl">{item.value}</span>;
                                  })}
                                </span>
                              )
                              : (
                                <span aria-hidden="true" data-fallback-asset={option.asset} className="text-7xl sm:text-8xl">
                                  {asset.value}
                                </span>
                              )
                        }
                      </span>


                      <span className="mt-4 text-lg font-extrabold leading-tight text-slate-800">
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
          className={[
            "mx-auto mt-7 flex min-h-14 max-w-md items-center justify-center rounded-2xl px-4 py-3 text-center text-xl font-extrabold",
            feedback === "Betul! Bagus."
              ? "bg-emerald-100 text-emerald-900"
              : feedback === "Cuba lagi."
                ? "bg-rose-100 text-rose-900"
                : "text-slate-800"
          ].join(" ")}
          data-testid="learner-feedback"
          data-feedback-state={
            feedback === "Betul! Bagus."
              ? "correct"
              : feedback === "Cuba lagi."
                ? "incorrect"
                : "idle"
          }
          aria-live="polite"
          aria-atomic="true"
        >
          {feedback && (
            <span className="inline-flex items-center gap-2">
              <span aria-hidden="true">
                {
                  feedback === "Betul! Bagus."
                    ? "✓"
                    : feedback === "Cuba lagi."
                      ? "↻"
                      : "●"
                }
              </span>
              <span>{feedback}</span>
            </span>
          )}
        </div>


        {completed && (
          <section
            className="mt-4 rounded-3xl border-2 border-emerald-200 bg-emerald-50 p-5 text-center"
            data-testid="learner-completion"
          >
            <span
              aria-hidden="true"
              className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-emerald-600 text-2xl font-black text-white"
            >
              ✓
            </span>
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
              className="mt-4 min-h-14 touch-manipulation rounded-2xl bg-slate-900 px-6 py-3 font-extrabold text-white transition active:scale-[0.98] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-slate-300"
            >
              Aktiviti seterusnya
            </button>
          </section>
        )}
      </section>
    </section>
  );
}
