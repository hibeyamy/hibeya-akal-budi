import {
  describe,
  expect,
  it
} from "vitest";

import {
  DEFAULT_ADAPTIVE_ACTIVATION_CONFIG,
  getAdaptiveRolloutBucket,
  resolveControlledAdaptiveActivity
} from "./adaptiveActivationPolicy";


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
      "activation",
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
    }
  ]
} as any;


describe(
  "controlled adaptive activation",
  () => {
    it(
      "defaults to legacy authority",
      () => {
        const decision =
          resolveControlledAdaptiveActivity(
            input,
            "learner-a"
          );

        expect(
          DEFAULT_ADAPTIVE_ACTIVATION_CONFIG
        ).toEqual({
          enabled:
            false,
          rolloutPercent:
            0
        });

        expect(
          decision?.authority
        ).toBe(
          "legacy"
        );

        expect(
          decision?.fallbackReason
        ).toBe(
          "disabled"
        );
      }
    );


    it(
      "keeps 0 percent rollout on legacy even when enabled",
      () => {
        const decision =
          resolveControlledAdaptiveActivity(
            input,
            "learner-a",
            {
              enabled:
                true,
              rolloutPercent:
                0
            }
          );

        expect(
          decision?.authority
        ).toBe(
          "legacy"
        );
      }
    );


    it(
      "uses adaptive authority for 100 percent rollout when the shadow decision is valid",
      () => {
        const decision =
          resolveControlledAdaptiveActivity(
            input,
            "learner-a",
            {
              enabled:
                true,
              rolloutPercent:
                100
            }
          );

        expect(
          decision
        ).not.toBeNull();

        expect(
          decision?.authority
        ).toBe(
          "adaptive"
        );

        expect(
          decision?.fallbackReason
        ).toBe(
          "adaptive-selected"
        );

        expect(
          activities.some(
            item =>
              item.id ===
              decision?.activity.id
          )
        ).toBe(
          true
        );
      }
    );


    it(
      "assigns the same learner to the same deterministic rollout bucket",
      () => {
        expect(
          getAdaptiveRolloutBucket(
            "learner-stable"
          )
        ).toBe(
          getAdaptiveRolloutBucket(
            "learner-stable"
          )
        );
      }
    );


    it(
      "falls back to legacy when the adaptive resolver throws",
      () => {
        const decision =
          resolveControlledAdaptiveActivity(
            input,
            "learner-a",
            {
              enabled:
                true,
              rolloutPercent:
                100
            },
            (() => {
              throw new Error(
                "simulated"
              );
            }) as any
          );

        expect(
          decision?.authority
        ).toBe(
          "legacy"
        );

        expect(
          decision?.fallbackReason
        ).toBe(
          "shadow-error"
        );
      }
    );


    it(
      "falls back to legacy when the adaptive resolver returns null",
      () => {
        const decision =
          resolveControlledAdaptiveActivity(
            input,
            "learner-a",
            {
              enabled:
                true,
              rolloutPercent:
                100
            },
            (() =>
              null) as any
          );

        expect(
          decision?.authority
        ).toBe(
          "legacy"
        );

        expect(
          decision?.fallbackReason
        ).toBe(
          "shadow-null"
        );
      }
    );


    it(
      "rejects an adaptive candidate outside the supplied catalogue",
      () => {
        const decision =
          resolveControlledAdaptiveActivity(
            input,
            "learner-a",
            {
              enabled:
                true,
              rolloutPercent:
                100
            },
            (() => ({
              authoritativeActivity:
                activities[0],
              adaptiveCandidate: {
                ...activities[0],
                id:
                  "not-in-catalogue"
              },
              authoritativeReason:
                "learning-need",
              adaptiveReason:
                "shadow-score",
              agrees:
                false,
              learningNeed:
                1,
              difficultyFit:
                1,
              adaptiveScore:
                1
            })) as any
          );

        expect(
          decision?.authority
        ).toBe(
          "legacy"
        );

        expect(
          decision?.fallbackReason
        ).toBe(
          "invalid-adaptive-candidate"
        );
      }
    );


    it(
      "keeps rollout cohort assignment bounded from 0 to 99",
      () => {
        for(
          const key
          of [
            "",
            "a",
            "learner-1",
            "learner-2",
            "very-long-learner-key-1234567890"
          ]
        ){
          const bucket =
            getAdaptiveRolloutBucket(
              key
            );

          expect(
            bucket
          ).toBeGreaterThanOrEqual(
            0
          );

          expect(
            bucket
          ).toBeLessThan(
            100
          );
        }
      }
    );
  }
);
