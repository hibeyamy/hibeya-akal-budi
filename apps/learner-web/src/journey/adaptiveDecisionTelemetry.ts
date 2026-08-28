import type {
  ControlledAdaptiveDecision
} from "./adaptiveActivationPolicy";

import {
  queueAndSyncAdaptiveObservation
} from "../services/adaptiveObservationSyncService";


export const ADAPTIVE_DECISION_EVENT =
  "hibeya:adaptive-decision";


export interface AdaptiveDecisionTelemetry {
  authority:
    ControlledAdaptiveDecision[
      "authority"
    ];

  fallbackReason:
    ControlledAdaptiveDecision[
      "fallbackReason"
    ];

  rolloutBucket:
    number;

  rolloutPercent:
    number;

  legacyActivityId:
    string;

  adaptiveActivityId:
    string | null;

  selectedActivityId:
    string;
}


export function toAdaptiveDecisionTelemetry(
  decision:
    ControlledAdaptiveDecision
):
  AdaptiveDecisionTelemetry {
  return {
    authority:
      decision.authority,
    fallbackReason:
      decision.fallbackReason,
    rolloutBucket:
      decision.rolloutBucket,
    rolloutPercent:
      decision.rolloutPercent,
    legacyActivityId:
      decision.legacyActivityId,
    adaptiveActivityId:
      decision.adaptiveActivityId,
    selectedActivityId:
      decision.activity.id
  };
}


export function emitAdaptiveDecisionTelemetry(
  decision:
    ControlledAdaptiveDecision
): void {
  const payload =
    toAdaptiveDecisionTelemetry(
      decision
    );

  void queueAndSyncAdaptiveObservation({
    ...payload,
    occurredAt:
      Date.now()
  });

  try {
    if (
      typeof window ===
        "undefined" ||
      typeof window.dispatchEvent !==
        "function"
    ) {
      return;
    }

    window.dispatchEvent(
      new CustomEvent(
        ADAPTIVE_DECISION_EVENT,
        {
          detail:
            payload
        }
      )
    );
  } catch {
    /*
     * Telemetry is explicitly non-blocking.
     * Learner selection must succeed even if event emission fails.
     */
  }
}
