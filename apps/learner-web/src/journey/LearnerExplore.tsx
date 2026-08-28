import type {
  ResolvedPlayableActivity
} from "@akal-budi/content-library";

export interface LearnerExploreProps {
  activities:
    readonly ResolvedPlayableActivity[];

  onBack:
    () => void;

  onOpenActivity:
    (
      activityId:
        string
    ) => void;
}

export function LearnerExplore({
  activities,
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

      {
        activities.length ===
          0
          ? (
              <div
                className="mt-6 rounded-2xl border-2 border-amber-200 bg-amber-50 p-5"
                role="status"
              >
                <p className="text-lg font-black text-slate-900">
                  Aktiviti untuk umur ini sedang disediakan
                </p>

                <p className="mt-2 text-sm font-medium leading-6 text-slate-600">
                  Tiada aktiviti yang telah diluluskan untuk julat umur profil ini dalam versi semasa.
                </p>
              </div>
            )
          : (
              <div className="mt-6 grid gap-4 sm:grid-cols-2">
                {
                  activities.map(
                    activity => (
                      <button
                        key={activity.id}
                        type="button"
                        onClick={
                          () =>
                            onOpenActivity(
                              activity.id
                            )
                        }
                        className="min-h-20 rounded-2xl border-2 border-emerald-200 bg-emerald-50 p-5 text-left focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-emerald-200"
                      >
                        <span className="block text-lg font-black text-slate-900">
                          {activity.titleMs}
                        </span>

                        <span className="mt-1 block text-sm font-medium text-slate-600">
                          Aktiviti yang sesuai untuk julat umur pembelajaran ini.
                        </span>
                      </button>
                    )
                  )
                }
              </div>
            )
      }
    </section>
  );
}
