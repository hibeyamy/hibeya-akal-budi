import {
  getEligibleActivitiesForLearner,
  type ResolvedPlayableActivity
} from "@akal-budi/content-library";

import type {
  LearnerAgeBand
} from "../../services/deviceActivationService";

import {
  resolveControlledAdaptiveActivity
} from "../../journey/adaptiveActivationPolicy";

import {
  emitAdaptiveDecisionTelemetry
} from "../../journey/adaptiveDecisionTelemetry";

import {
  getAdaptiveRuntimeConfig
} from "../../journey/adaptiveRuntimeConfig";

import {
  resolveNextLearnerActivity
} from "../../journey/nextLearnerActivity.service";


export interface LearnerActivitySelectionInput {
  childId?:
    string;

  ageBand:
    LearnerAgeBand;

  lastCompletedActivityId:
    string | null;

  completedActivityIds?:
    readonly string[];

  masteredSkillIds?:
    readonly string[];

  skillProgress?:
    readonly import("../../journey/nextLearnerActivity.service").LearnerSkillProgress[];
}


export function selectLearnerActivity({
  childId,
  ageBand,
  lastCompletedActivityId,
  completedActivityIds = [],
  masteredSkillIds = [],
  skillProgress = []
}: LearnerActivitySelectionInput):
  ResolvedPlayableActivity |
  null {
  const input = {
    activities:
      getEligibleActivitiesForLearner({
        ageBand,
        masteredSkillIds
      }),

    completedActivityIds,

    lastCompletedActivityId,

    skillProgress
  };

  /*
   * Backward-compatible fail-safe:
   * existing callers/tests without a learner identity stay on
   * the proven legacy resolver.
   */
  if (!childId) {
    return resolveNextLearnerActivity(
      input
    );
  }

  const decision =
    resolveControlledAdaptiveActivity(
      input,
      childId,
      getAdaptiveRuntimeConfig()
    );

  if (!decision) {
    return null;
  }

  emitAdaptiveDecisionTelemetry(
    decision
  );

  return decision.activity;
}
