import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const playerFile = path.join(root, "apps/learner-web/src/features/play/ActivityPlayer.tsx");
let player = await fs.readFile(playerFile, "utf8");

const replacements = [
[
`      <main className="mx-auto w-full max-w-3xl px-4 py-6 sm:px-6 sm:py-10">`,
`      <main
        className="mx-auto w-full max-w-3xl px-4 py-6 sm:px-6 sm:py-10"
        data-testid="activity-player"
        data-activity-id={activity.id}
        data-activity-state={
          completed
            ? "completed"
            : answers.length > 0
              ? "retry"
              : "idle"
        }
        data-answer-count={answers.length}
      >`
],
[
`      <section
        className="rounded-[2rem] border border-amber-100 bg-white p-5 shadow-sm sm:p-8"
        data-testid="learner-activity-card"
      >`,
`      <section
        className="rounded-[2rem] border border-amber-100 bg-white p-5 shadow-sm sm:p-8"
        data-testid="learner-activity-card"
        data-session-mode={localSession ? "local" : "remote"}
      >`
],
[
`        <div
          className={[
            "mx-auto mt-7 flex min-h-14 max-w-md items-center justify-center rounded-2xl px-4 py-3 text-center text-xl font-extrabold",`,
`        <div
          className={[
            "mx-auto mt-7 flex min-h-14 max-w-md items-center justify-center rounded-2xl px-4 py-3 text-center text-xl font-extrabold",`
],
[
`          data-testid="learner-feedback"
          aria-live="polite"`,
`          data-testid="learner-feedback"
          data-feedback-state={
            feedback === "Betul! Bagus."
              ? "correct"
              : feedback === "Cuba lagi."
                ? "incorrect"
                : "idle"
          }
          aria-live="polite"`
]
];

for (const [before, after] of replacements) {
  if (!player.includes(before)) {
    throw new Error("Expected ActivityPlayer state boundary not found:\\n" + before.slice(0, 180));
  }
  player = player.replace(before, after);
}

await fs.writeFile(playerFile, player, "utf8");
console.log("PATCHED: ActivityPlayer state observability");
