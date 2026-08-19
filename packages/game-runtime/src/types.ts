import type { ActivityContent } from "@akal-budi/content-schema";

export interface GameSessionContext {
  activity: ActivityContent;
  startedAt: number;
}

export interface GameAnswer {
  optionId: string;
  correct: boolean;
  answeredAt: number;
}

export interface GameSessionResult {
  activityId: string;
  activityVersion: number;
  correct: number;
  incorrect: number;
  attempts: number;
  durationSeconds: number;
  completedAt: number;
}

export interface GameMechanicRuntime {
  readonly mechanicId: string;

  start(activity: ActivityContent): GameSessionContext;

  submitAnswer(
    context: GameSessionContext,
    optionId: string
  ): GameAnswer;

  complete(
    context: GameSessionContext,
    answers: GameAnswer[]
  ): GameSessionResult;
}
