import {
  useState
} from "react";

import {
  getAsset
} from "@akal-budi/assets";


const reviewActivity = {
  id:
    "beza-bunga-raya-001",

  title: {
    ms:
      "Yang Mana Berbeza?",

    en:
      "Which One Is Different?"
  },

  instruction: {
    ms:
      "Cari bunga raya yang berbeza",

    en:
      "Find the hibiscus that is different"
  },

  options: [
    {
      id: "hibiscus-red-left",
      asset: "hibiscus-red",
      correct: false
    },
    {
      id: "hibiscus-red-right",
      asset: "hibiscus-red",
      correct: false
    },
    {
      id: "hibiscus-yellow-different",
      asset: "hibiscus-yellow",
      correct: true
    }
  ]
} as const;


function DraftActivityVisualReview() {
  const [
    selectedId,
    setSelectedId
  ] =
    useState<string | null>(
      null
    );

  const [
    feedback,
    setFeedback
  ] =
    useState<string | null>(
      null
    );


  function handleAnswer(
    optionId: string
  ) {
    const option =
      reviewActivity.options.find(
        item =>
          item.id ===
          optionId
      );

    if (!option) {
      return;
    }

    setSelectedId(
      optionId
    );

    setFeedback(
      option.correct
        ? "Betul! Bagus."
        : "Cuba lagi."
    );
  }


  return (
    <main
      data-review-activity-id={
        reviewActivity.id
      }
      data-review-only="true"
      className="mx-auto flex min-h-screen max-w-3xl flex-col px-4 py-6 sm:px-6 sm:py-10"
    >
      <header className="mb-8">
        <div className="inline-flex rounded-full bg-amber-100 px-3 py-1 text-xs font-extrabold uppercase tracking-[0.16em] text-amber-800">
          Draf - semakan visual sahaja
        </div>

        <p className="mt-4 text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
          HIBEYA
        </p>

        <h1 className="mt-1 text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">
          Akal Budi
        </h1>

        <p className="mt-1 text-sm text-slate-600 sm:text-base">
          Membina Akal. Menyemai Budi.
        </p>
      </header>

      <section className="rounded-[2rem] bg-white p-5 shadow-sm sm:p-8">
        <div className="mb-7 text-center">
          <p className="text-sm font-semibold text-amber-700">
            Semakan aktiviti draf
          </p>

          <h2 className="mt-2 text-2xl font-bold text-slate-900 sm:text-3xl">
            {reviewActivity.title.ms}
          </h2>

          <p className="mt-3 text-lg text-slate-700 sm:text-xl">
            {reviewActivity.instruction.ms}
          </p>

          <p className="mt-2 text-sm text-slate-500">
            {reviewActivity.title.en} - {reviewActivity.instruction.en}
          </p>
        </div>

        <div
          data-testid="draft-choice-grid"
          className="grid grid-cols-1 gap-4 sm:grid-cols-3"
        >
          {reviewActivity.options.map(
            option => {
              const asset =
                getAsset(
                  option.asset
                );

              const isSelected =
                selectedId ===
                option.id;

              return (
                <button
                  key={option.id}
                  type="button"
                  data-testid="draft-choice"
                  data-option-id={option.id}
                  data-correct={
                    option.correct
                      ? "true"
                      : "false"
                  }
                  onClick={
                    () =>
                      handleAnswer(
                        option.id
                      )
                  }
                  aria-label={
                    asset.alt.ms
                  }
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
                  {asset.type === "image"
                    ? (
                        <img
                          src={asset.value}
                          alt=""
                          aria-hidden="true"
                          draggable={false}
                          data-asset-id={option.asset}
                          className="h-40 w-40 select-none object-contain sm:h-44 sm:w-44"
                        />
                      )
                    : (
                        <span
                          aria-hidden="true"
                          data-asset-id={option.asset}
                          className="text-7xl sm:text-8xl"
                        >
                          {asset.value}
                        </span>
                      )
                  }

                  <span className="mt-4 text-base font-semibold text-slate-700">
                    {asset.alt.ms}
                  </span>
                </button>
              );
            }
          )}
        </div>

        <div
          className="mt-7 min-h-10 text-center text-xl font-bold text-slate-800"
          aria-live="polite"
        >
          {feedback}
        </div>

        <aside className="mt-6 rounded-3xl border border-dashed border-amber-300 bg-amber-50 p-4 text-sm leading-6 text-amber-950">
          Draf ini tidak berada dalam katalog pembelajaran produksi.
          Interaksi di halaman ini adalah untuk semakan visual sahaja dan tidak merekod kemajuan, sesi atau penguasaan kemahiran.
        </aside>
      </section>
    </main>
  );
}


export default {
  title:
    "Review/Draft Activity"
};


export function BezaBungaRaya001() {
  return (
    <DraftActivityVisualReview />
  );
}
