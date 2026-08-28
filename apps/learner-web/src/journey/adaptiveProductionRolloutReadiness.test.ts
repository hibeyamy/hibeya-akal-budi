import {
  describe,
  expect,
  it
} from "vitest";

import {
  evaluateProductionRolloutReadiness,
  MIN_OPERATIONAL_ADAPTIVE_DECISIONS_FOR_EXPANSION
} from "./adaptiveProductionRolloutReadiness";


function cleanEvidence() {
  return {
    syntheticPopulation:
      10000,
    eligibleCount:
      100,
    cohortLeakageCount:
      0,
    piiLeakageCount:
      0,
    prerequisiteViolationCount:
      0,
    invalidAdaptiveCandidateCount:
      0,
    adaptiveErrorCount:
      0,
    telemetryExpectedCount:
      10000,
    telemetryObservedCount:
      10000,
    killSwitchLegacyCount:
      10000,
    killSwitchPopulation:
      10000,
    deterministicMismatchCount:
      0,
    operationalAdaptiveDecisionCount:
      0,
    operationalCriticalIncidentCount:
      0
  };
}


describe(
  "production rollout readiness gate",
  () => {
    it(
      "allows technical entry readiness while blocking expansion without operational evidence",
      () => {
        const decision =
          evaluateProductionRolloutReadiness(
            cleanEvidence()
          );

        expect(
          decision.productionOnePercentEntryReady
        ).toBe(
          true
        );

        expect(
          decision.expansionBeyondOnePercentReady
        ).toBe(
          false
        );

        expect(
          decision.code
        ).toBe(
          "NOT_ENOUGH_OPERATIONAL_EVIDENCE"
        );
      }
    );


    it(
      "returns no-go for every critical zero-tolerance failure class",
      () => {
        const mutations = [
          {
            key:
              "cohortLeakageCount",
            value:
              1
          },
          {
            key:
              "piiLeakageCount",
            value:
              1
          },
          {
            key:
              "prerequisiteViolationCount",
            value:
              1
          },
          {
            key:
              "invalidAdaptiveCandidateCount",
            value:
              1
          },
          {
            key:
              "adaptiveErrorCount",
            value:
              1
          },
          {
            key:
              "deterministicMismatchCount",
            value:
              1
          }
        ] as const;

        for(
          const mutation
          of mutations
        ){
          const evidence =
            cleanEvidence();

          (
            evidence as any
          )[
            mutation.key
          ] =
            mutation.value;

          expect(
            evaluateProductionRolloutReadiness(
              evidence
            ).productionOnePercentEntryReady
          ).toBe(
            false
          );
        }
      }
    );


    it(
      "requires complete telemetry and full kill-switch recovery",
      () => {
        expect(
          evaluateProductionRolloutReadiness({
            ...cleanEvidence(),
            telemetryObservedCount:
              9999
          }).productionOnePercentEntryReady
        ).toBe(
          false
        );

        expect(
          evaluateProductionRolloutReadiness({
            ...cleanEvidence(),
            killSwitchLegacyCount:
              9999
          }).productionOnePercentEntryReady
        ).toBe(
          false
        );
      }
    );


    it(
      "requires broad synthetic evidence before production entry",
      () => {
        expect(
          evaluateProductionRolloutReadiness({
            ...cleanEvidence(),
            syntheticPopulation:
              999,
            eligibleCount:
              10,
            telemetryExpectedCount:
              999,
            telemetryObservedCount:
              999,
            killSwitchLegacyCount:
              999,
            killSwitchPopulation:
              999
          }).productionOnePercentEntryReady
        ).toBe(
          false
        );
      }
    );


    it(
      "allows expansion readiness only after the operational evidence guardrail is met",
      () => {
        const decision =
          evaluateProductionRolloutReadiness({
            ...cleanEvidence(),
            operationalAdaptiveDecisionCount:
              MIN_OPERATIONAL_ADAPTIVE_DECISIONS_FOR_EXPANSION,
            operationalCriticalIncidentCount:
              0
          });

        expect(
          decision.expansionBeyondOnePercentReady
        ).toBe(
          true
        );
      }
    );


    it(
      "blocks expansion when any operational critical incident exists",
      () => {
        const decision =
          evaluateProductionRolloutReadiness({
            ...cleanEvidence(),
            operationalAdaptiveDecisionCount:
              MIN_OPERATIONAL_ADAPTIVE_DECISIONS_FOR_EXPANSION,
            operationalCriticalIncidentCount:
              1
          });

        expect(
          decision.expansionBeyondOnePercentReady
        ).toBe(
          false
        );
      }
    );
  }
);
