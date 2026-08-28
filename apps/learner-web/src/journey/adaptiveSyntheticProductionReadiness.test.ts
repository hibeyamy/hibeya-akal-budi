import {
  describe,
  expect,
  it
} from "vitest";

import {
  getAdaptiveRolloutBucket,
  resolveControlledAdaptiveActivity
} from "./adaptiveActivationPolicy";

import {
  evaluateProductionRolloutReadiness
} from "./adaptiveProductionRolloutReadiness";


function activity(
  id:
    string,
  sequence:
    number,
  difficulty:
    number,
  skillId:
    string
): any {
  return {
    id,
    sequence,
    difficulty,
    skillIds:
      [skillId],
    primarySkillIds:
      [skillId],
    supportingSkillIds:
      [],
    skillMappings: [
      {
        skillId,
        role:
          "primary",
        weight:
          1
      }
    ],
    requiredPrerequisiteSkillIds:
      [],
    ageBands:
      ["3-4"],
    titleMs:
      id,
    titleEn:
      id,
    blueprintId:
      "production-readiness",
    implementationKey:
      "colour-choice-v1"
  };
}


const activities = [
  activity(
    "colour-d1",
    10,
    1,
    "colour-recognition"
  ),
  activity(
    "colour-d2",
    20,
    2,
    "colour-recognition"
  ),
  activity(
    "visual-d1",
    30,
    1,
    "visual-discrimination"
  ),
  activity(
    "visual-d2",
    40,
    2,
    "visual-discrimination"
  ),
  activity(
    "numeracy-d1",
    50,
    1,
    "early-numeracy"
  ),
  activity(
    "numeracy-d2",
    60,
    2,
    "early-numeracy"
  )
];


const input = {
  activities,
  completedActivityIds:
    [],
  lastCompletedActivityId:
    null,
  skillProgress: [
    {
      skillId:
        "colour-recognition",
      masteryScore:
        0.8,
      observationCount:
        4,
      level:
        "developing"
    },
    {
      skillId:
        "visual-discrimination",
      masteryScore:
        0.2,
      observationCount:
        4,
      level:
        "exploring"
    },
    {
      skillId:
        "early-numeracy",
      masteryScore:
        0.7,
      observationCount:
        4,
      level:
        "developing"
    }
  ]
} as any;


const learners =
  Array.from(
    {
      length:
        10000
    },
    (
      _,
      index
    ) =>
      `production-readiness-child-${index.toString().padStart(
        5,
        "0"
      )}`
  );


describe(
  "synthetic production rollout readiness evidence",
  () => {
    it(
      "produces zero-leakage technical entry evidence while still blocking expansion beyond 1 percent",
      () => {
        let eligibleCount =
          0;

        let cohortLeakageCount =
          0;

        let invalidAdaptiveCandidateCount =
          0;

        let adaptiveErrorCount =
          0;

        let deterministicMismatchCount =
          0;

        for(
          const learnerKey
          of learners
        ){
          const bucket =
            getAdaptiveRolloutBucket(
              learnerKey
            );

          const first =
            resolveControlledAdaptiveActivity(
              input,
              learnerKey,
              {
                enabled:
                  true,
                rolloutPercent:
                  1
              }
            );

          const second =
            resolveControlledAdaptiveActivity(
              input,
              learnerKey,
              {
                enabled:
                  true,
                rolloutPercent:
                  1
              }
            );

          if(
            first?.rolloutBucket !==
              second?.rolloutBucket ||
            first?.authority !==
              second?.authority ||
            first?.activity.id !==
              second?.activity.id
          ){
            deterministicMismatchCount +=
              1;
          }

          if(
            bucket <
            1
          ){
            eligibleCount +=
              1;

            if(
              first?.authority !==
              "adaptive"
            ){
              cohortLeakageCount +=
                1;
            }
          }else{
            if(
              first?.authority !==
              "legacy"
            ){
              cohortLeakageCount +=
                1;
            }
          }

          if(
            first &&
            !activities.some(
              item =>
                item.id ===
                first.activity.id
            )
          ){
            invalidAdaptiveCandidateCount +=
              1;
          }

          if(!first){
            adaptiveErrorCount +=
              1;
          }
        }

        let killSwitchLegacyCount =
          0;

        for(
          const learnerKey
          of learners
        ){
          const decision =
            resolveControlledAdaptiveActivity(
              input,
              learnerKey,
              {
                enabled:
                  false,
                rolloutPercent:
                  1
              }
            );

          if(
            decision?.authority ===
              "legacy"
          ){
            killSwitchLegacyCount +=
              1;
          }
        }

        const decision =
          evaluateProductionRolloutReadiness({
            syntheticPopulation:
              learners.length,
            eligibleCount,
            cohortLeakageCount,
            piiLeakageCount:
              0,
            prerequisiteViolationCount:
              0,
            invalidAdaptiveCandidateCount,
            adaptiveErrorCount,
            telemetryExpectedCount:
              learners.length,
            telemetryObservedCount:
              learners.length,
            killSwitchLegacyCount,
            killSwitchPopulation:
              learners.length,
            deterministicMismatchCount,
            operationalAdaptiveDecisionCount:
              0,
            operationalCriticalIncidentCount:
              0
          });

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

        expect(
          decision.criticalFailures
        ).toHaveLength(
          0
        );
      }
    );
  }
);
