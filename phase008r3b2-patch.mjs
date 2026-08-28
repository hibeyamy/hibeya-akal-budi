import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const file = path.join(process.cwd(), "apps/learner-web/src/features/play/ActivityPlayer.tsx");
let s = await fs.readFile(file, "utf8");

const replacements = [
[`      <section className="rounded-[2rem] bg-white p-5 shadow-sm sm:p-8">
        <div className="mb-7 text-center">`,
`      <section
        className="rounded-[2rem] border border-amber-100 bg-white p-5 shadow-sm sm:p-8"
        data-testid="learner-activity-card"
      >
        <div className="mb-7 text-center">
          <span
            aria-hidden="true"
            className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-amber-100 text-2xl"
          >
            ★
          </span>`],

[`          <p className="mt-3 text-lg text-slate-700 sm:text-xl">
            {
              activity
                .instruction
                .ms
            }
          </p>`,
`          <p className="mx-auto mt-3 max-w-xl text-lg font-semibold leading-relaxed text-slate-700 sm:text-xl">
            {
              activity
                .instruction
                .ms
            }
          </p>`],

[`                        "flex min-h-40 touch-manipulation flex-col items-center justify-center",
                        "rounded-3xl border-2 px-4 py-6",
                        "transition duration-150 active:scale-95",
                        "focus:outline-none focus:ring-4 focus:ring-amber-200",`,
`                        "relative flex min-h-40 touch-manipulation flex-col items-center justify-center",
                        "rounded-3xl border-2 px-4 py-6 shadow-sm",
                        "transition duration-150 active:scale-[0.98]",
                        "focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-amber-200",`],

[`                          ? "border-emerald-500 bg-emerald-50"
                          : selectedState === "incorrect"
                            ? "border-rose-400 bg-rose-50"
                            : selectedState === "selected"
                              ? "border-amber-500 bg-amber-50"
                              : "border-slate-200 bg-slate-50 hover:border-amber-300"`,
`                          ? "border-emerald-500 bg-emerald-50 shadow-md"
                          : selectedState === "incorrect"
                            ? "border-rose-500 bg-rose-50 shadow-md"
                            : selectedState === "selected"
                              ? "border-amber-500 bg-amber-50 shadow-md"
                              : "border-slate-200 bg-slate-50 hover:border-amber-300 hover:bg-amber-50/40"`],

[`                    >
                      <span
                        className="flex h-40 w-40 items-center justify-center overflow-hidden sm:h-44 sm:w-44"`,
`                    >
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
                        className="flex h-40 w-40 items-center justify-center overflow-hidden sm:h-44 sm:w-44"`],

[`                      <span className="mt-4 text-base font-semibold text-slate-700">`,
`                      <span className="mt-4 text-lg font-extrabold leading-tight text-slate-800">`],

[`        <div
          className="mt-7 min-h-10 text-center text-xl font-bold text-slate-800"
          aria-live="polite"
        >
          {feedback}
        </div>`,
`        <div
          className={[
            "mx-auto mt-7 flex min-h-14 max-w-md items-center justify-center rounded-2xl px-4 py-3 text-center text-xl font-extrabold",
            feedback === "Betul! Bagus."
              ? "bg-emerald-100 text-emerald-900"
              : feedback === "Cuba lagi."
                ? "bg-rose-100 text-rose-900"
                : "text-slate-800"
          ].join(" ")}
          data-testid="learner-feedback"
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
        </div>`],

[`          <section className="mt-4 rounded-3xl bg-emerald-50 p-5 text-center">`,
`          <section
            className="mt-4 rounded-3xl border-2 border-emerald-200 bg-emerald-50 p-5 text-center"
            data-testid="learner-completion"
          >
            <span
              aria-hidden="true"
              className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-emerald-600 text-2xl font-black text-white"
            >
              ✓
            </span>`],

[`              className="mt-4 rounded-2xl bg-slate-900 px-5 py-3 font-semibold text-white"`,
`              className="mt-4 min-h-14 touch-manipulation rounded-2xl bg-slate-900 px-6 py-3 font-extrabold text-white transition active:scale-[0.98] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-slate-300"`]
];

for (const [before, after] of replacements) {
  if (!s.includes(before)) throw new Error("Expected visual-system boundary not found:\\n" + before.slice(0, 140));
  s = s.replace(before, after);
}

await fs.writeFile(file, s, "utf8");
console.log("PATCHED: child-facing visual system");
