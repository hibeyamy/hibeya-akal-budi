import {
  resolveAdaptiveSelectionShadow
} from "./adaptiveSelectionShadow";

import {
  resolveNextLearnerActivity
} from "./nextLearnerActivity.service";

import type {
  NextLearnerActivityInput
} from "./nextLearnerActivity.service";


export interface AdaptiveActivationConfig {
  enabled:
    boolean;

  rolloutPercent:
    number;
}


export const DEFAULT_ADAPTIVE_ACTIVATION_CONFIG:
  AdaptiveActivationConfig = {
    enabled:
      false,

    rolloutPercent:
      0
  };


export type AdaptiveAuthority =
  | "legacy"
  | "adaptive";


export type AdaptiveFallbackReason =
  | "disabled"
  | "outside-cohort"
  | "legacy-null"
  | "shadow-null"
  | "shadow-error"
  | "invalid-adaptive-candidate"
  | "adaptive-selected";


export interface ControlledAdaptiveDecision {
  activity:
    NonNullable<
      ReturnType<
        typeof resolveNextLearnerActivity
      >
    >;

  authority:
    AdaptiveAuthority;

  fallbackReason:
    AdaptiveFallbackReason;

  rolloutBucket:
    number;

  rolloutPercent:
    number;

  legacyActivityId:
    string;

  adaptiveActivityId:
    string | null;
}


type ShadowResolver =
  typeof resolveAdaptiveSelectionShadow;


function clampRolloutPercent(
  value:
    number
): number {
  if (
    !Number.isFinite(
      value
    )
  ) {
    return 0;
  }

  return Math.min(
    100,
    Math.max(
      0,
      value
    )
  );
}


export function getAdaptiveRolloutBucket(
  learnerKey:
    string
): number {
  let hash =
    2166136261;

  for (
    let index =
      0;
    index <
      learnerKey.length;
    index +=
      1
  ) {
    hash ^=
      learnerKey.charCodeAt(
        index
      );

    hash =
      Math.imul(
        hash,
        16777619
      );
  }

  return (
    hash >>>
      0
  ) %
    100;
}


function isValidAdaptiveCandidate(
  candidateId:
    string,
  input:
    NextLearnerActivityInput
): boolean {
  return input.activities.some(
    activity =>
      activity.id ===
      candidateId
  );
}


export function resolveControlledAdaptiveActivity(
  input:
    NextLearnerActivityInput,
  learnerKey:
    string,
  config:
    AdaptiveActivationConfig =
      DEFAULT_ADAPTIVE_ACTIVATION_CONFIG,
  shadowResolver:
    ShadowResolver =
      resolveAdaptiveSelectionShadow
):
  ControlledAdaptiveDecision |
  null {
  const legacy =
    resolveNextLearnerActivity(
      input
    );

  const rolloutPercent =
    clampRolloutPercent(
      config.rolloutPercent
    );

  const rolloutBucket =
    getAdaptiveRolloutBucket(
      learnerKey
    );

  if (!legacy) {
    return null;
  }

  const base = {
    rolloutBucket,
    rolloutPercent,
    legacyActivityId:
      legacy.id
  };

  if (
    !config.enabled ||
    rolloutPercent <=
      0
  ) {
    return {
      activity:
        legacy,
      authority:
        "legacy",
      fallbackReason:
        "disabled",
      adaptiveActivityId:
        null,
      ...base
    };
  }

  if (
    rolloutBucket >=
    rolloutPercent
  ) {
    return {
      activity:
        legacy,
      authority:
        "legacy",
      fallbackReason:
        "outside-cohort",
      adaptiveActivityId:
        null,
      ...base
    };
  }

  try {
    const shadow =
      shadowResolver(
        input
      );

    if (!shadow) {
      return {
        activity:
          legacy,
        authority:
          "legacy",
        fallbackReason:
          "shadow-null",
        adaptiveActivityId:
          null,
        ...base
      };
    }

    const adaptive =
      shadow.adaptiveCandidate;

    if (
      !isValidAdaptiveCandidate(
        adaptive.id,
        input
      )
    ) {
      return {
        activity:
          legacy,
        authority:
          "legacy",
        fallbackReason:
          "invalid-adaptive-candidate",
        adaptiveActivityId:
          adaptive.id,
        ...base
      };
    }

    return {
      activity:
        adaptive,
      authority:
        "adaptive",
      fallbackReason:
        "adaptive-selected",
      adaptiveActivityId:
        adaptive.id,
      ...base
    };
  } catch {
    return {
      activity:
        legacy,
      authority:
        "legacy",
      fallbackReason:
        "shadow-error",
      adaptiveActivityId:
        null,
      ...base
    };
  }
}
