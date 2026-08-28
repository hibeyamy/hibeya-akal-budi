import {
  getActivityDifficultyFit,
  getActivityLearningNeed,
  resolveNextLearnerActivityDecision
} from "./nextLearnerActivity.service";

import type {
  NextLearnerActivityInput
} from "./nextLearnerActivity.service";


export const ADAPTIVE_SHADOW_WEIGHTS = {
  learningNeed:
    0.8,

  difficultyFit:
    0.2
} as const;


export type AdaptiveShadowReason =
  | "shadow-score"
  | "catalogue-fallback";


export interface AdaptiveSelectionShadowDecision {
  authoritativeActivity:
    NonNullable<
      ReturnType<
        typeof resolveNextLearnerActivityDecision
      >
    >["activity"];

  adaptiveCandidate:
    NonNullable<
      ReturnType<
        typeof resolveNextLearnerActivityDecision
      >
    >["activity"];

  authoritativeReason:
    NonNullable<
      ReturnType<
        typeof resolveNextLearnerActivityDecision
      >
    >["reason"];

  adaptiveReason:
    AdaptiveShadowReason;

  agrees:
    boolean;

  learningNeed:
    number;

  difficultyFit:
    number;

  adaptiveScore:
    number;
}


function scoreCandidate(
  activity:
    AdaptiveSelectionShadowDecision["adaptiveCandidate"],
  skillProgress:
    NonNullable<
      NextLearnerActivityInput[
        "skillProgress"
      ]
    >
): {
  learningNeed:
    number;

  difficultyFit:
    number;

  adaptiveScore:
    number;
} {
  const learningNeed =
    getActivityLearningNeed(
      activity,
      skillProgress
    );

  const difficultyFit =
    getActivityDifficultyFit(
      activity,
      skillProgress
    );

  return {
    learningNeed,
    difficultyFit,
    adaptiveScore:
      learningNeed *
        ADAPTIVE_SHADOW_WEIGHTS.learningNeed +
      difficultyFit *
        ADAPTIVE_SHADOW_WEIGHTS.difficultyFit
  };
}


export function resolveAdaptiveSelectionShadow(
  input:
    NextLearnerActivityInput
):
  AdaptiveSelectionShadowDecision |
  null {
  const authoritative =
    resolveNextLearnerActivityDecision(
      input
    );

  if (!authoritative) {
    return null;
  }

  const completed =
    new Set(
      input.completedActivityIds
    );

  const uncompleted =
    input.activities.filter(
      activity =>
        !completed.has(
          activity.id
        )
    );

  const basePool =
    uncompleted.length >
      0
      ? uncompleted
      : input.activities;

  const withoutImmediateRepeat =
    basePool.filter(
      activity =>
        activity.id !==
        input.lastCompletedActivityId
    );

  const candidatePool =
    withoutImmediateRepeat.length >
      0
      ? withoutImmediateRepeat
      : basePool;

  const skillProgress =
    input.skillProgress ??
    [];

  const ranked =
    candidatePool
      .map(
        activity => ({
          activity,
          ...scoreCandidate(
            activity,
            skillProgress
          )
        })
      )
      .sort(
        (
          left,
          right
        ) => {
          const scoreDifference =
            right.adaptiveScore -
            left.adaptiveScore;

          if (
            Math.abs(
              scoreDifference
            ) >
              0.000001
          ) {
            return scoreDifference;
          }

          const sequenceDifference =
            left.activity.sequence -
            right.activity.sequence;

          if (
            sequenceDifference !==
            0
          ) {
            return sequenceDifference;
          }

          return left.activity.id.localeCompare(
            right.activity.id
          );
        }
      );

  const adaptive =
    ranked[0];

  if (!adaptive) {
    return {
      authoritativeActivity:
        authoritative.activity,
      adaptiveCandidate:
        authoritative.activity,
      authoritativeReason:
        authoritative.reason,
      adaptiveReason:
        "catalogue-fallback",
      agrees:
        true,
      learningNeed:
        authoritative.learningNeed,
      difficultyFit:
        authoritative.difficultyFit,
      adaptiveScore:
        authoritative.learningNeed *
          ADAPTIVE_SHADOW_WEIGHTS.learningNeed +
        authoritative.difficultyFit *
          ADAPTIVE_SHADOW_WEIGHTS.difficultyFit
    };
  }

  return {
    authoritativeActivity:
      authoritative.activity,
    adaptiveCandidate:
      adaptive.activity,
    authoritativeReason:
      authoritative.reason,
    adaptiveReason:
      "shadow-score",
    agrees:
      authoritative.activity.id ===
      adaptive.activity.id,
    learningNeed:
      adaptive.learningNeed,
    difficultyFit:
      adaptive.difficultyFit,
    adaptiveScore:
      adaptive.adaptiveScore
  };
}
