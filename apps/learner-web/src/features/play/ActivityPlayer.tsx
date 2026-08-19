import {
  useEffect,
  useMemo,
  useState
} from "react";

import { getAsset } from "@akal-budi/assets";
import { warnaMerah001 } from "@akal-budi/content-library";
import { getGameMechanic } from "@akal-budi/game-mechanics";

import {
  addLocalAnswer,
  completeLocalSession,
  createLocalSession,
  getLatestIncompleteSession
} from "@akal-budi/offline";

import { useNetworkStatus } from "../../hooks/useNetworkStatus";

function createSessionId() {
  return crypto.randomUUID();
}

export function ActivityPlayer() {
  const activity = warnaMerah001;
  const network = useNetworkStatus();

  const mechanic = useMemo(
    () => getGameMechanic(activity.mechanic),
    [activity.mechanic]
  );

  const [context] = useState(() =>
    mechanic.start(activity)
  );

  const [sessionId] = useState(
    createSessionId
  );

  const [answers, setAnswers] = useState<
    ReturnType<typeof mechanic.submitAnswer>[]
  >([]);

  const [selectedId, setSelectedId] =
    useState<string | null>(null);

  const [feedback, setFeedback] =
    useState<string | null>(null);

  const [sessionInitialised, setSessionInitialised] =
    useState(false);

  const [recoveryAvailable, setRecoveryAvailable] =
    useState(false);

  useEffect(() => {
    void getLatestIncompleteSession()
      .then((session) => {
        setRecoveryAvailable(Boolean(session));
      });
  }, []);

  async function ensureSession() {
    if (sessionInitialised) {
      return;
    }

    await createLocalSession({
      id: sessionId,
      activityId: activity.id,
      activityVersion: activity.version,
      startedAt: context.startedAt
    });

    setSessionInitialised(true);
  }

  async function handleAnswer(
    optionId: string
  ) {
    await ensureSession();

    const answer = mechanic.submitAnswer(
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

    setAnswers(nextAnswers);
    setSelectedId(optionId);

    if (answer.correct) {
      setFeedback("Betul! Bagus.");

      const result = mechanic.complete(
        context,
        nextAnswers
      );

      await completeLocalSession(
        sessionId,
        result
      );

      setRecoveryAvailable(false);
    } else {
      setFeedback("Cuba lagi.");
    }
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
      </header>

      {recoveryAvailable && (
        <div className="mb-4 rounded-2xl bg-slate-100 px-4 py-3 text-sm font-medium text-slate-700">
          Aktiviti sebelumnya belum selesai.
        </div>
      )}

      <section className="rounded-[2rem] bg-white p-5 shadow-sm sm:p-8">
        <div className="mb-7 text-center">
          <p className="text-sm font-semibold text-amber-700">
            Aktiviti pertama
          </p>

          <h2 className="mt-2 text-2xl font-bold text-slate-900 sm:text-3xl">
            {activity.title.ms}
          </h2>

          <p className="mt-3 text-lg text-slate-700 sm:text-xl">
            {activity.instruction.ms}
          </p>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          {activity.options.map((option) => {
            const asset = getAsset(
              option.asset
            );

            const isSelected =
              selectedId === option.id;

            return (
              <button
                key={option.id}
                type="button"
                onClick={() =>
                  void handleAnswer(
                    option.id
                  )
                }
                aria-label={asset.alt.ms}
                className={[
                  "flex min-h-40 touch-manipulation flex-col items-center justify-center",
                  "rounded-3xl border-2 px-4 py-6",
                  "transition duration-150 active:scale-95",
                  "focus:outline-none focus:ring-4 focus:ring-amber-200",
                  isSelected
                    ? "border-amber-500 bg-amber-50"
                    : "border-slate-200 bg-slate-50 hover:border-amber-300"
                ].join(" ")}
              >
                <span
                  aria-hidden="true"
                  className="text-7xl sm:text-8xl"
                >
                  {asset.value}
                </span>

                <span className="mt-4 text-base font-semibold text-slate-700">
                  {asset.alt.ms}
                </span>
              </button>
            );
          })}
        </div>

        <div
          className="mt-7 min-h-10 text-center text-xl font-bold text-slate-800"
          aria-live="polite"
        >
          {feedback}
        </div>
      </section>
    </main>
  );
}
