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

  progressAvailable?:
    boolean;

  title?:
    string;

  subtitle?:
    string;
}

export function LearnerShell({
  children,
  learnerName = "Kawan kecil",
  progressPercent = 0,
  progressAvailable = true,
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

  const progressLabel =
    progressAvailable
      ? `${Math.round(safeProgress)}%`
      : "Belum tersedia";

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
            aria-label={
              progressAvailable
                ? `Kemajuan ${Math.round(safeProgress)} peratus`
                : "Kemajuan belum tersedia kerana tiada kandungan diluluskan untuk julat umur ini"
            }
          >
            <div className="mb-1 flex items-center justify-between gap-3 text-xs font-semibold text-slate-600">
              <span>
                Kemajuan
              </span>

              <span>
                {progressLabel}
              </span>
            </div>

            <div className="h-3 overflow-hidden rounded-full bg-slate-100">
              <div
                className="h-full rounded-full bg-amber-500 transition-[width] motion-reduce:transition-none"
                style={{
                  width:
                    progressAvailable
                      ? `${safeProgress}%`
                      : "0%"
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
