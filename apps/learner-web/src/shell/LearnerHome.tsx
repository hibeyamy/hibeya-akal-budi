export interface LearnerHomeProps {
  contentAvailable:
    boolean;

  onContinue?:
    () => void;

  onExplore?:
    () => void;
}

export function LearnerHome({
  contentAvailable,
  onContinue,
  onExplore
}: LearnerHomeProps) {
  return (
    <div className="grid gap-5 lg:grid-cols-[1.4fr_1fr]">
      <section className="rounded-3xl bg-white p-6 shadow-sm ring-1 ring-slate-100 sm:p-8">
        <p className="text-sm font-bold uppercase tracking-wide text-amber-700">
          {
            contentAvailable
              ? "Aktiviti seterusnya"
              : "Kandungan pembelajaran"
          }
        </p>

        <h2 className="mt-2 text-2xl font-black text-slate-900">
          {
            contentAvailable
              ? "Warna di sekeliling kita"
              : "Aktiviti untuk umur ini sedang disediakan"
          }
        </h2>

        <p className="mt-3 max-w-xl text-base leading-7 text-slate-600">
          {
            contentAvailable
              ? "Kenal warna melalui objek yang dekat dengan kehidupan harian."
              : "Belum ada aktiviti yang telah diluluskan untuk julat umur profil ini dalam versi semasa."
          }
        </p>

        {
          contentAvailable
            ? (
                <button
                  type="button"
                  onClick={onContinue}
                  className="mt-6 min-h-14 rounded-2xl bg-amber-500 px-6 py-3 text-lg font-extrabold text-slate-950 shadow-sm transition hover:bg-amber-400 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-amber-300 motion-reduce:transition-none"
                  style={{ minHeight: "56px" }}
                >
                  Sambung belajar
                </button>
              )
            : null
        }
      </section>

      <section className="rounded-3xl bg-white p-6 shadow-sm ring-1 ring-slate-100 sm:p-8">
        <p className="text-sm font-bold uppercase tracking-wide text-emerald-700">
          Teroka
        </p>

        <h2 className="mt-2 text-2xl font-black text-slate-900">
          Aktiviti lain
        </h2>

        <p className="mt-3 text-base leading-7 text-slate-600">
          {
            contentAvailable
              ? "Pilih aktiviti mengikut minat tanpa tekanan atau ganjaran berlebihan."
              : "Semak kandungan yang tersedia untuk julat umur profil ini."
          }
        </p>

        <button
          type="button"
          onClick={onExplore}
          className="mt-6 min-h-14 rounded-2xl border-2 border-emerald-300 bg-emerald-50 px-6 py-3 text-lg font-extrabold text-emerald-900 transition hover:bg-emerald-100 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-emerald-200 motion-reduce:transition-none"
          style={{ minHeight: "56px" }}
        >
          Lihat aktiviti
        </button>
      </section>
    </div>
  );
}
