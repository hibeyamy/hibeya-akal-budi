import type {
  GameAnswer,
  GameSessionContext,
  GameSessionResult
} from "./types";

export function createSessionContext(
  activity: GameSessionContext["activity"]
): GameSessionContext {
  return {
    activity,
    startedAt: Date.now()
  };
}

export function createSessionResult(
  context: GameSessionContext,
  answers: GameAnswer[]
): GameSessionResult {
  const completedAt = Date.now();

  const correct = answers.filter((answer) => answer.correct).length;
  const incorrect = answers.length - correct;

  return {
    activityId: context.activity.id,
    activityVersion: context.activity.version,
    correct,
    incorrect,
    attempts: answers.length,
    durationSeconds: Math.max(
      0,
      Math.round((completedAt - context.startedAt) / 1000)
    ),
    completedAt
  };
}
