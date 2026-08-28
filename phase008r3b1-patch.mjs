import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const file = path.join(root, "apps/learner-web/src/features/play/ActivityPlayer.tsx");
let source = await fs.readFile(file, "utf8");

const oldBlock = `                  const isSelected =
                    selectedId ===
                    option.id;


                  return (
                    <button
                      key={
                        option.id
                      }
                      type="button"
                      disabled={
                        completed
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
                      className={[
                        "flex min-h-40 touch-manipulation flex-col items-center justify-center",
                        "rounded-3xl border-2 px-4 py-6",
                        "transition duration-150 active:scale-95",
                        "focus:outline-none focus:ring-4 focus:ring-amber-200",
                        completed
                          ? "cursor-default opacity-80"
                          : "",
                        isSelected
                          ? "border-amber-500 bg-amber-50"
                          : "border-slate-200 bg-slate-50 hover:border-amber-300"
                      ].join(
                        " "
                      )}
                    >
                      {
                        asset.type ===
                        "image"
                          ? (
                            <img
                              src={
                                asset.value
                              }
                              alt=""
                              aria-hidden="true"
                              draggable={
                                false
                              }
                              className="h-40 w-40 select-none object-contain sm:h-44 sm:w-44"
                            />
                          )
                          : (
                            <span
                              aria-hidden="true"
                              className="text-7xl sm:text-8xl"
                            >
                              {
                                asset.value
                              }
                            </span>
                          )
                      }


                      <span className="mt-4 text-base font-semibold text-slate-700">
                        {
                          asset
                            .alt
                            .ms
                        }
                      </span>
                    </button>
                  );`;

const newBlock = `                  const isSelected =
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
                        completed
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
                        "flex min-h-40 touch-manipulation flex-col items-center justify-center",
                        "rounded-3xl border-2 px-4 py-6",
                        "transition duration-150 active:scale-95",
                        "focus:outline-none focus:ring-4 focus:ring-amber-200",
                        completed
                          ? "cursor-default opacity-80"
                          : "",
                        selectedState === "correct"
                          ? "border-emerald-500 bg-emerald-50"
                          : selectedState === "incorrect"
                            ? "border-rose-400 bg-rose-50"
                            : selectedState === "selected"
                              ? "border-amber-500 bg-amber-50"
                              : "border-slate-200 bg-slate-50 hover:border-amber-300"
                      ].join(
                        " "
                      )}
                    >
                      <span
                        className="flex h-40 w-40 items-center justify-center overflow-hidden sm:h-44 sm:w-44"
                        data-testid="learner-choice-visual"
                      >
                        {
                          asset.type ===
                          "image"
                            ? (
                              <img
                                src={
                                  asset.value
                                }
                                alt=""
                                aria-hidden="true"
                                draggable={
                                  false
                                }
                                data-production-asset={
                                  option.asset
                                }
                                className="h-full w-full select-none object-contain"
                              />
                            )
                            : (
                              <span
                                aria-hidden="true"
                                data-fallback-asset={
                                  option.asset
                                }
                                className="text-7xl sm:text-8xl"
                              >
                                {
                                  asset.value
                                }
                              </span>
                            )
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
                  );`;

if (!source.includes(oldBlock)) {
  throw new Error("Expected ActivityPlayer option-rendering boundary was not found. Repository was not modified.");
}

source = source.replace(oldBlock, newBlock);
await fs.writeFile(file, source, "utf8");
console.log("PATCHED: ActivityPlayer production visual boundary");
