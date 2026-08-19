import {
  useEffect,
  useMemo,
  useState
} from "react";

import {
  analyseLearningSessions,
  learningObjectives,
  signalPresentation,
  type LearningSignal
} from "@akal-budi/learning-insights";

import {
  getChildLearningSessions,
  toLearningSessionInput,
  type ParentLearningSession
} from "../../services/progressService";

import {
  getErrorMessage
} from "../../utils/errorMessage";


export interface ProgressChild {
  id: string;
  nickname: string;
  ageBand: string;
}


interface ProgressDashboardProps {
  children:
    readonly ProgressChild[];
}


export function ProgressDashboard({
  children
}: ProgressDashboardProps) {
  const [
    selectedChildId,
    setSelectedChildId
  ] =
    useState("");

  const [
    sessions,
    setSessions
  ] =
    useState<
      ParentLearningSession[]
    >([]);

  const [
    loading,
    setLoading
  ] =
    useState(false);

  const [
    message,
    setMessage
  ] =
    useState<string | null>(
      null
    );


  useEffect(() => {
    if (
      children.length === 0
    ) {
      setSelectedChildId("");
      setSessions([]);

      return;
    }


    const stillExists =
      children.some(
        (child) =>
          child.id ===
          selectedChildId
      );


    if (!stillExists) {
      setSelectedChildId(
        children[0]?.id ??
        ""
      );
    }
  }, [
    children,
    selectedChildId
  ]);


  useEffect(() => {
    if (!selectedChildId) {
      setSessions([]);

      return;
    }


    void loadProgress(
      selectedChildId
    );
  }, [
    selectedChildId
  ]);


  async function loadProgress(
    childId: string
  ) {
    setLoading(true);
    setMessage(null);


    try {
      const result =
        await getChildLearningSessions(
          childId
        );

      setSessions(
        result
      );
    } catch (error) {
      setMessage(
        getErrorMessage(error)
      );
    } finally {
      setLoading(false);
    }
  }


  const selectedChild =
    children.find(
      (child) =>
        child.id ===
        selectedChildId
    );


  const summary =
    useMemo(
      () =>
        analyseLearningSessions(
          sessions.map(
            toLearningSessionInput
          )
        ),
      [sessions]
    );


  const latestSession =
    sessions[0];


  if (
    children.length === 0
  ) {
    return (
      <section className="mt-6 rounded-3xl bg-white p-6 shadow-sm">
        <p className="text-sm font-bold uppercase tracking-[0.15em] text-amber-700">
          Perkembangan Pembelajaran
        </p>

        <h2 className="mt-2 text-xl font-bold text-slate-900">
          Pemerhatian Pembelajaran
        </h2>

        <p className="mt-3 text-sm leading-6 text-slate-600">
          Cipta profil anak terlebih dahulu untuk melihat pengalaman pembelajaran.
        </p>
      </section>
    );
  }


  return (
    <section className="mt-6 rounded-3xl bg-white p-6 shadow-sm">
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.15em] text-amber-700">
            Perkembangan Pembelajaran
          </p>

          <h2 className="mt-2 text-2xl font-bold text-slate-900">
            Pemerhatian Pembelajaran
          </h2>

          <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
            Ringkasan ini menunjukkan pengalaman yang telah diterokai.
            Ia bukan ujian perkembangan atau perbandingan dengan kanak-kanak lain.
          </p>
        </div>


        <div className="min-w-52">
          <label className="block text-sm font-semibold text-slate-700">
            Profil anak
          </label>

          <select
            value={
              selectedChildId
            }
            onChange={
              (event) =>
                setSelectedChildId(
                  event.target.value
                )
            }
            className="mt-2 w-full rounded-2xl border border-slate-300 px-4 py-3"
          >
            {children.map(
              (child) => (
                <option
                  key={
                    child.id
                  }
                  value={
                    child.id
                  }
                >
                  {
                    child.nickname
                  }
                </option>
              )
            )}
          </select>
        </div>
      </div>


      {message && (
        <p className="mt-5 rounded-2xl bg-amber-50 px-4 py-3 text-sm text-amber-900">
          {message}
        </p>
      )}


      {loading ? (
        <div className="mt-6 rounded-3xl bg-slate-50 p-6">
          <p className="text-sm text-slate-600">
            Memuatkan pengalaman pembelajaran...
          </p>
        </div>
      ) : sessions.length === 0 ? (
        <EmptyProgress
          childName={
            selectedChild
              ?.nickname ??
            "Anak"
          }
        />
      ) : (
        <>
          <div className="mt-6 grid gap-4 sm:grid-cols-3">
            <SummaryCard
              label="Aktiviti diterokai"
              value={
                summary.totalSessions
                  .toString()
              }
              description="Sesi pembelajaran yang telah diselesaikan."
            />

            <SummaryCard
              label="Masa pembelajaran"
              value={
                formatLearningMinutes(
                  summary
                    .totalLearningMinutes
                )
              }
              description="Anggaran masa dalam aktiviti pembelajaran."
            />

            <SummaryCard
              label="Fokus pembelajaran"
              value={
                summary.objectives
                  .length
                  .toString()
              }
              description="Jenis objektif pembelajaran yang telah ditemui."
            />
          </div>


          {latestSession && (
            <div className="mt-5 rounded-2xl bg-slate-50 px-5 py-4">
              <p className="text-xs font-bold uppercase tracking-[0.12em] text-slate-500">
                Aktiviti terkini
              </p>

              <p className="mt-1 font-semibold text-slate-900">
                {
                  formatActivityName(
                    latestSession
                      .activityId
                  )
                }
              </p>

              <p className="mt-1 text-sm text-slate-600">
                {
                  formatDateTime(
                    latestSession
                      .completedAt
                  )
                }
              </p>
            </div>
          )}


          <div className="mt-8">
            <h3 className="text-lg font-bold text-slate-900">
              Apa yang sedang diterokai
            </h3>

            <p className="mt-1 text-sm leading-6 text-slate-600">
              Isyarat ini berubah apabila lebih banyak pengalaman pembelajaran dikumpulkan.
            </p>


            {summary.objectives
              .length === 0 ? (
              <p className="mt-4 rounded-2xl bg-slate-50 px-4 py-4 text-sm text-slate-600">
                Aktiviti telah direkodkan tetapi belum mempunyai pemetaan objektif pembelajaran.
              </p>
            ) : (
              <div className="mt-4 grid gap-4 lg:grid-cols-2">
                {summary.objectives.map(
                  (
                    observation
                  ) => {
                    const objective =
                      learningObjectives.find(
                        (item) =>
                          item.id ===
                          observation.objectiveId
                      );

                    if (
                      !objective
                    ) {
                      return null;
                    }


                    const presentation =
                      signalPresentation[
                        observation.signal
                      ];


                    return (
                      <article
                        key={
                          observation
                            .objectiveId
                        }
                        className="rounded-3xl border border-slate-200 p-5"
                      >
                        <div className="flex flex-wrap items-start justify-between gap-3">
                          <div>
                            <p className="font-bold text-slate-900">
                              {
                                objective
                                  .titleMs
                              }
                            </p>

                            <p className="mt-1 text-sm leading-6 text-slate-600">
                              {
                                objective
                                  .descriptionMs
                              }
                            </p>
                          </div>

                          <SignalBadge
                            signal={
                              observation
                                .signal
                            }
                          />
                        </div>


                        <div className="mt-4 border-t border-slate-100 pt-4">
                          <p className="text-sm font-semibold text-slate-800">
                            {
                              presentation
                                .labelMs
                            }
                          </p>

                          <p className="mt-1 text-sm leading-6 text-slate-600">
                            {
                              presentation
                                .descriptionMs
                            }
                          </p>


                          <p className="mt-3 text-xs text-slate-500">
                            Diterokai{" "}
                            {
                              observation
                                .exposureCount
                            }{" "}
                            kali dalam rekod aktiviti.
                          </p>
                        </div>
                      </article>
                    );
                  }
                )}
              </div>
            )}
          </div>


          <ParentSuggestion
            signals={
              summary.objectives.map(
                (
                  observation
                ) =>
                  observation.signal
              )
            }
          />


          <div className="mt-8">
            <h3 className="text-lg font-bold text-slate-900">
              Aktiviti Terkini
            </h3>

            <div className="mt-4 space-y-3">
              {sessions
                .slice(
                  0,
                  10
                )
                .map(
                  (session) => (
                    <article
                      key={
                        session.id
                      }
                      className="flex flex-col justify-between gap-3 rounded-2xl border border-slate-200 px-4 py-4 sm:flex-row sm:items-center"
                    >
                      <div>
                        <p className="font-semibold text-slate-900">
                          {
                            formatActivityName(
                              session
                                .activityId
                            )
                          }
                        </p>

                        <p className="mt-1 text-sm text-slate-500">
                          {
                            formatDateTime(
                              session
                                .completedAt
                            )
                          }
                        </p>
                      </div>

                      <p className="text-sm text-slate-600">
                        {
                          formatDuration(
                            session
                              .durationSeconds
                          )
                        }
                      </p>
                    </article>
                  )
                )}
            </div>
          </div>
        </>
      )}
    </section>
  );
}


function EmptyProgress({
  childName
}: {
  childName: string;
}) {
  return (
    <div className="mt-6 rounded-3xl bg-slate-50 p-6">
      <p className="font-bold text-slate-900">
        Belum ada pengalaman pembelajaran.
      </p>

      <p className="mt-2 text-sm leading-6 text-slate-600">
        Selepas {childName} menyelesaikan aktiviti melalui Learner Mode,
        pemerhatian pembelajaran akan muncul di sini.
      </p>
    </div>
  );
}


function SummaryCard({
  label,
  value,
  description
}: {
  label: string;
  value: string;
  description: string;
}) {
  return (
    <article className="rounded-3xl bg-slate-50 p-5">
      <p className="text-sm font-semibold text-slate-600">
        {label}
      </p>

      <p className="mt-2 text-3xl font-bold text-slate-900">
        {value}
      </p>

      <p className="mt-2 text-xs leading-5 text-slate-500">
        {description}
      </p>
    </article>
  );
}


function SignalBadge({
  signal
}: {
  signal: LearningSignal;
}) {
  const presentation =
    signalPresentation[
      signal
    ];


  return (
    <span className="rounded-full bg-amber-50 px-3 py-1 text-xs font-semibold text-amber-800">
      {
        presentation
          .labelMs
      }
    </span>
  );
}


function ParentSuggestion({
  signals
}: {
  signals:
    readonly LearningSignal[];
}) {
  const hasExploring =
    signals.includes(
      "exploring"
    );

  const hasDeveloping =
    signals.includes(
      "developing"
    );


  let text =
    "Teruskan memberi peluang untuk meneroka melalui permainan, perbualan dan aktiviti harian tanpa tekanan untuk mendapatkan jawapan yang sempurna.";


  if (hasExploring) {
    text =
      "Ada pengalaman yang masih baru. Cuba bawa pembelajaran keluar daripada skrin — cari warna, bentuk atau objek yang sama ketika bermain dan menjalani rutin harian.";
  } else if (
    hasDeveloping
  ) {
    text =
      "Pengalaman sudah mula berulang. Gunakan situasi harian untuk mengukuhkan kefahaman, contohnya ketika makan, mengemas, berjalan atau membeli-belah.";
  }


  return (
    <aside className="mt-8 rounded-3xl bg-amber-50 p-5">
      <p className="text-sm font-bold text-amber-900">
        Idea untuk ibu bapa
      </p>

      <p className="mt-2 text-sm leading-7 text-slate-700">
        {text}
      </p>

      <p className="mt-3 text-xs leading-5 text-slate-500">
        Cadangan ini ialah idea aktiviti umum dan bukan penilaian perkembangan klinikal.
      </p>
    </aside>
  );
}


function formatLearningMinutes(
  minutes: number
) {
  if (
    minutes < 1
  ) {
    return "<1 min";
  }

  return `${minutes} min`;
}


function formatDuration(
  seconds: number
) {
  if (
    seconds < 60
  ) {
    return `${seconds} saat`;
  }


  const minutes =
    Math.round(
      seconds / 60
    );


  return `${minutes} min`;
}


function formatDateTime(
  value: string
) {
  return new Date(
    value
  ).toLocaleString(
    "ms-MY",
    {
      dateStyle:
        "medium",

      timeStyle:
        "short"
    }
  );
}


function formatActivityName(
  activityId: string
) {
  const names:
    Record<
      string,
      string
    > = {
      "warna-merah-001":
        "Cari Warna Merah"
    };


  return (
    names[
      activityId
    ] ??
    "Aktiviti Akal Budi"
  );
}
