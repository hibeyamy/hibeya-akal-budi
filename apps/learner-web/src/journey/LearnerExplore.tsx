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
