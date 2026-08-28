import {
  describe,
  expect,
  it
} from "vitest";

import {
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
      "synthetic-1-percent",
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


const syntheticLearners =
  Array.from(
    {
      length:
        500
    },
    (
      _,
      index
    ) =>
      `synthetic-child-${index.toString().padStart(
        4,
        "0"
      )}`
  );


describe(
  "synthetic 1 percent cohort proof",
  () => {
    it(
      "assigns cohort membership deterministically",
      () => {
        const first =
          syntheticLearners.map(
            learnerKey => ({
              learnerKey,
              bucket:
                getAdaptiveRolloutBucket(
                  learnerKey
                )
            })
          );

        const second =
          syntheticLearners.map(
            learnerKey => ({
              learnerKey,
              bucket:
                getAdaptiveRolloutBucket(
                  learnerKey
                )
            })
          );

        expect(
          second
        ).toEqual(
          first
        );
      }
    );


    it(
      "grants adaptive authority only to learners in bucket 0 at 1 percent rollout",
      () => {
        const rows =
          syntheticLearners.map(
            learnerKey => {
              const bucket =
                getAdaptiveRolloutBucket(
                  learnerKey
                );

              const decision =
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

              return {
                learnerKey,
                bucket,
                authority:
                  decision?.authority,
                fallbackReason:
                  decision?.fallbackReason
              };
            }
          );

        const eligible =
          rows.filter(
            row =>
              row.bucket <
              1
          );

        const adaptive =
          rows.filter(
            row =>
              row.authority ===
              "adaptive"
          );

        const legacy =
          rows.filter(
            row =>
              row.authority ===
              "legacy"
          );

        expect(
          adaptive.length
        ).toBe(
          eligible.length
        );

        expect(
          legacy.length
        ).toBe(
          rows.length -
          eligible.length
        );

        for(
          const row
          of rows
        ){
          if(
            row.bucket <
            1
          ){
            expect(
              row.authority
            ).toBe(
              "adaptive"
            );

            expect(
              row.fallbackReason
            ).toBe(
              "adaptive-selected"
            );
          }else{
            expect(
              row.authority
            ).toBe(
              "legacy"
            );

            expect(
              row.fallbackReason
            ).toBe(
              "outside-cohort"
            );
          }
        }
      }
    );


    it(
      "produces a realistic synthetic cohort size without requiring exactly 1 percent",
      () => {
        const buckets =
          syntheticLearners.map(
            learnerKey =>
              getAdaptiveRolloutBucket(
                learnerKey
              )
          );

        const eligibleCount =
          buckets.filter(
            bucket =>
              bucket <
              1
          ).length;

        expect(
          eligibleCount
        ).toBeGreaterThan(
          0
        );

        expect(
          eligibleCount
        ).toBeLessThan(
          syntheticLearners.length /
          10
        );
      }
    );


    it(
      "keeps repeated sessions for the same learner in the same authority state",
      () => {
        for(
          const learnerKey
          of syntheticLearners.slice(
            0,
            50
          )
        ){
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

          expect(
            second?.authority
          ).toBe(
            first?.authority
          );

          expect(
            second?.rolloutBucket
          ).toBe(
            first?.rolloutBucket
          );

          expect(
            second?.activity.id
          ).toBe(
            first?.activity.id
          );
        }
      }
    );


    it(
      "returns the entire synthetic population to legacy when the kill switch is disabled",
      () => {
        for(
          const learnerKey
          of syntheticLearners
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
      }
    );


    it(
      "keeps invalid adaptive decisions on legacy even for eligible cohort members",
      () => {
        const eligibleLearner =
          syntheticLearners.find(
            learnerKey =>
              getAdaptiveRolloutBucket(
                learnerKey
              ) <
              1
          );

        expect(
          eligibleLearner
        ).toBeTruthy();

        const decision =
          resolveControlledAdaptiveActivity(
            input,
            eligibleLearner!,
            {
              enabled:
                true,
              rolloutPercent:
                1
            },
            (() => ({
              authoritativeActivity:
                activities[0],
              adaptiveCandidate: {
                ...activities[0],
                id:
                  "invalid-outside-catalogue"
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
  }
);
