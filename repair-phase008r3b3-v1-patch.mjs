import fs from "node:fs/promises";
import path from "node:path";

const file = path.join(process.cwd(), "apps/learner-web/src/features/play/ActivityPlayer.tsx");
let s = await fs.readFile(file, "utf8");

const changes = [
[
`    <main className="mx-auto flex min-h-screen max-w-3xl flex-col px-4 py-6 sm:px-6 sm:py-10">`,
`    <main
      className="mx-auto flex min-h-screen max-w-3xl flex-col px-4 py-6 sm:px-6 sm:py-10"
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
`        data-testid="learner-activity-card"
      >`,
`        data-testid="learner-activity-card"
        data-session-mode={localSession ? "local" : "remote"}
      >`
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

for (const [before, after] of changes) {
  const count = s.split(before).length - 1;
  if (count !== 1) {
    throw new Error(`Expected exactly one boundary, found ${count}: ${before.slice(0,120)}`);
  }
  s = s.replace(before, after);
}
await fs.writeFile(file, s, "utf8");
console.log("PATCHED: ActivityPlayer state observability using exact post-R3B.2 boundary");
