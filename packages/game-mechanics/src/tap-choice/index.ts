import type { ActivityContent } from "@akal-budi/content-schema";

import {
  createSessionContext,
  createSessionResult,
  type GameAnswer,
  type GameMechanicRuntime,
  type GameSessionContext,
  type GameSessionResult
} from "@akal-budi/game-runtime";

export class TapChoiceMechanic implements GameMechanicRuntime {
  readonly mechanicId = "tap-choice";

  start(activity: ActivityContent): GameSessionContext {
    if (activity.mechanic !== this.mechanicId) {
      throw new Error(
        `TapChoiceMechanic cannot run activity mechanic: ${activity.mechanic}`
      );
    }

    return createSessionContext(activity);
  }

  submitAnswer(
    context: GameSessionContext,
    optionId: string
  ): GameAnswer {
    const option = context.activity.options.find(
      (candidate) => candidate.id === optionId
    );

    if (!option) {
      throw new Error(`Unknown option: ${optionId}`);
    }

    return {
      optionId,
      correct: option.correct,
      answeredAt: Date.now()
    };
  }

  complete(
    context: GameSessionContext,
    answers: GameAnswer[]
  ): GameSessionResult {
    return createSessionResult(context, answers);
  }
}
