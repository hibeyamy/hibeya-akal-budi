export type ProductionRolloutReadinessCode =
  | "PRODUCTION_1_PERCENT_ENTRY_READY"
  | "PRODUCTION_1_PERCENT_NO_GO"
  | "NOT_ENOUGH_OPERATIONAL_EVIDENCE";


export interface ProductionRolloutReadinessEvidence {
  syntheticPopulation:
    number;

  eligibleCount:
    number;

  cohortLeakageCount:
    number;

  piiLeakageCount:
    number;

  prerequisiteViolationCount:
    number;

  invalidAdaptiveCandidateCount:
    number;

  adaptiveErrorCount:
    number;

  telemetryExpectedCount:
    number;

  telemetryObservedCount:
    number;

  killSwitchLegacyCount:
    number;

  killSwitchPopulation:
    number;

  deterministicMismatchCount:
    number;

  operationalAdaptiveDecisionCount:
    number;

  operationalCriticalIncidentCount:
    number;
}


export interface ProductionRolloutReadinessDecision {
  code:
    ProductionRolloutReadinessCode;

  productionOnePercentEntryReady:
    boolean;

  expansionBeyondOnePercentReady:
    boolean;

  criticalFailures:
    string[];

  telemetryCompleteness:
    number;

  syntheticEligibleRate:
    number;

  operationalAdaptiveDecisionCount:
    number;
}


/*
 * Operational evidence required before increasing beyond 1%.
 *
 * This is a conservative engineering rollout guardrail, not a
 * curriculum or pedagogical threshold.
 */
export const MIN_OPERATIONAL_ADAPTIVE_DECISIONS_FOR_EXPANSION =
  200;


export function evaluateProductionRolloutReadiness(
  evidence:
    ProductionRolloutReadinessEvidence
):
  ProductionRolloutReadinessDecision {
  const criticalFailures:
    string[] = [];

  const telemetryCompleteness =
    evidence.telemetryExpectedCount >
      0
      ? evidence.telemetryObservedCount /
        evidence.telemetryExpectedCount
      : 0;

  const syntheticEligibleRate =
    evidence.syntheticPopulation >
      0
      ? evidence.eligibleCount /
        evidence.syntheticPopulation
      : 0;

  if(
    evidence.syntheticPopulation <
      1000
  ){
    criticalFailures.push(
      "synthetic-population-too-small"
    );
  }

  if(
    evidence.eligibleCount <=
      0
  ){
    criticalFailures.push(
      "no-synthetic-eligible-learners"
    );
  }

  if(
    evidence.cohortLeakageCount !==
      0
  ){
    criticalFailures.push(
      "cohort-leakage"
    );
  }

  if(
    evidence.piiLeakageCount !==
      0
  ){
    criticalFailures.push(
      "pii-leakage"
    );
  }

  if(
    evidence.prerequisiteViolationCount !==
      0
  ){
    criticalFailures.push(
      "prerequisite-violation"
    );
  }

  if(
    evidence.invalidAdaptiveCandidateCount !==
      0
  ){
    criticalFailures.push(
      "invalid-adaptive-candidate"
    );
  }

  if(
    evidence.adaptiveErrorCount !==
      0
  ){
    criticalFailures.push(
      "adaptive-error"
    );
  }

  if(
    telemetryCompleteness !==
      1
  ){
    criticalFailures.push(
      "telemetry-incomplete"
    );
  }

  if(
    evidence.killSwitchPopulation <=
      0 ||
    evidence.killSwitchLegacyCount !==
      evidence.killSwitchPopulation
  ){
    criticalFailures.push(
      "kill-switch-failure"
    );
  }

  if(
    evidence.deterministicMismatchCount !==
      0
  ){
    criticalFailures.push(
      "non-deterministic-cohort"
    );
  }

  const productionOnePercentEntryReady =
    criticalFailures.length ===
      0;

  const expansionBeyondOnePercentReady =
    productionOnePercentEntryReady &&
    evidence.operationalAdaptiveDecisionCount >=
      MIN_OPERATIONAL_ADAPTIVE_DECISIONS_FOR_EXPANSION &&
    evidence.operationalCriticalIncidentCount ===
      0;

  let code:
    ProductionRolloutReadinessCode;

  if(
    !productionOnePercentEntryReady
  ){
    code =
      "PRODUCTION_1_PERCENT_NO_GO";
  }else if(
    !expansionBeyondOnePercentReady
  ){
    code =
      "NOT_ENOUGH_OPERATIONAL_EVIDENCE";
  }else{
    code =
      "PRODUCTION_1_PERCENT_ENTRY_READY";
  }

  return {
    code,
    productionOnePercentEntryReady,
    expansionBeyondOnePercentReady,
    criticalFailures,
    telemetryCompleteness,
    syntheticEligibleRate,
    operationalAdaptiveDecisionCount:
      evidence.operationalAdaptiveDecisionCount
  };
}
