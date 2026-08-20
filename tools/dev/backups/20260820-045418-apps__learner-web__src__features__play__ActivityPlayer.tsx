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
  getLatestIncompleteSession,
  processPendingSessions,
  type StoredSession
} from "@akal-budi/offline";

import {
  useNetworkStatus
} from "../../hooks/useNetworkStatus";

import {
  localSyncProvider
} from "../../services/localSyncProvider";

import {
  resolveRuntimeActivity
} from "./resolvePlayableActivity";


const DEFAULT_ACTIVITY_ID =
  "warna-merah-001";


function createSessionId():
  string {
  return crypto.randomUUID();
}


export function ActivityPlayer() {
  const network =
    useNetworkStatus();


  const runtimeActivity =
    useMemo(
      () =>
        resolveRuntimeActivity(
          DEFAULT_ACTIVITY_ID
        ),
      []
    );


  if (!runtimeActivity) {
    return (
      <main className="mx-auto flex min-h-screen max-w-3xl flex-col items-center justify-center px-4 py-10">
        <section className="w-full rounded-[2rem] bg-white p-6 text-center shadow-sm sm:p-8">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
            HIBEYA
          </p>

          <h1 className="mt-2 text-3xl font-bold text-slate-900">
            Akal Budi
          </h1>

          <p className="mt-5 text-slate-600">
            Aktiviti ini belum tersedia.
          </p>
        </section>
      </main>
    );
  }


  return (
    <ResolvedActivityPlayer
      runtimeActivity={
        runtimeActivity
      }
      network={network}
    />
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
}


function ResolvedActivityPlayer({
  runtimeActivity,
  network
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


  const [context] =
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


  useEffect(() => {
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
  }, [
    activity.id
  ]);


  useEffect(() => {
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
  }, [
    network.online
  ]);


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


      setRecoverySession(
        null
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


        {syncMessage &&
          network.online && (
            <div className="mt-3 inline-flex rounded-full bg-emerald-100 px-3 py-1 text-sm font-semibold text-emerald-800">
              {
                syncMessage
              }
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
                        isSelected
                          ? "border-amber-500 bg-amber-50"
                          : "border-slate-200 bg-slate-50 hover:border-amber-300"
                      ].join(
                        " "
                      )}
                    >
                      <span
                        aria-hidden="true"
                        className="text-7xl sm:text-8xl"
                      >
                        {
                          asset
                            .value
                        }
                      </span>


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
          {
            feedback
          }
        </div>
      </section>
    </main>
  );
}
