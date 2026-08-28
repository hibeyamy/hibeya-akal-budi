import {
  describe,
  expect,
  it
} from "vitest";

import type {
  ResolvedPlayableActivity
} from "@akal-budi/content-library";

import {
  getActivityDifficultyFit,
  getActivityLearningNeed,
  resolveNextLearnerActivity,
  resolveNextLearnerActivityDecision,
  selectRemediationActivity
} from "./nextLearnerActivity.service";


function activity(
  id: string,
  sequence: number,
  skillId: string
): ResolvedPlayableActivity {
  return {
    id,
    blueprintId:
      "test-blueprint",
    version:
      1,
    enabled:
      true,
    sequence,
    difficulty:
      sequence >= 20
        ? 2
        : 1,
    skillIds:
      [skillId],
    skillMappings: [
      {
        skillId,
        role:
          "primary",
        weight:
          1
      }
    ],
    primarySkillIds:
      [skillId],
    requiredPrerequisiteSkillIds:
      [],
    ageBands:
      ["3-4"],
    titleMs:
      id,
    titleEn:
      id,
    implementationKey:
      "test",
    blueprint:
      {} as ResolvedPlayableActivity["blueprint"]
  };
}


describe(
  "resolveNextLearnerActivity",
  () => {
    const first =
      activity(
        "first",
        10,
        "skill-a"
      );

    const second =
      activity(
        "second",
        20,
        "skill-b"
      );

    const activities =
      [
        first,
        second
      ];


    it(
      "preserves catalogue order when mastery detail is unavailable",
      () => {
        expect(
          resolveNextLearnerActivity({
            activities,
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null
          })?.id
        ).toBe(
          "first"
        );
      }
    );


    it(
      "prioritises a weaker skill while unfinished content remains",
      () => {
        expect(
          resolveNextLearnerActivity({
            activities,
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  0.9,
                observationCount:
                  3,
                level:
                  "mastered"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  0.2,
                observationCount:
                  2,
                level:
                  "exploring"
              }
            ]
          })?.id
        ).toBe(
          "second"
        );
      }
    );


    it(
      "never replaces unfinished progression with a completed remediation activity",
      () => {
        expect(
          resolveNextLearnerActivity({
            activities,
            completedActivityIds:
              ["first"],
            lastCompletedActivityId:
              "first",
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  0.05,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  0.9,
                observationCount:
                  3,
                level:
                  "mastered"
              }
            ]
          })?.id
        ).toBe(
          "second"
        );
      }
    );


    it(
      "selects completed content targeting the weakest skill only after normal progression is exhausted",
      () => {
        expect(
          resolveNextLearnerActivity({
            activities,
            completedActivityIds:
              [
                "first",
                "second"
              ],
            lastCompletedActivityId:
              "second",
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  0.15,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  0.65,
                observationCount:
                  2,
                level:
                  "developing"
              }
            ]
          })?.id
        ).toBe(
          "first"
        );
      }
    );


    it(
      "falls back to cyclic catalogue order when all observed skills are mastered",
      () => {
        expect(
          resolveNextLearnerActivity({
            activities,
            completedActivityIds:
              [
                "first",
                "second"
              ],
            lastCompletedActivityId:
              "first",
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  1,
                observationCount:
                  3,
                level:
                  "mastered"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  1,
                observationCount:
                  3,
                level:
                  "mastered"
              }
            ]
          })?.id
        ).toBe(
          "second"
        );
      }
    );


    it(
      "uses catalogue sequence as deterministic remediation tie-break",
      () => {
        expect(
          selectRemediationActivity({
            activities,
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  0.4,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  0.4,
                observationCount:
                  2,
                level:
                  "exploring"
              }
            ]
          })?.id
        ).toBe(
          "first"
        );
      }
    );


    it(
      "returns zero learning need for a mastered primary skill",
      () => {
        expect(
          getActivityLearningNeed(
            first,
            [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  1,
                observationCount:
                  3,
                level:
                  "mastered"
              }
            ]
          )
        ).toBe(
          0
        );
      }
    );

    it(
      "prefers sufficiently observed weakness over a single sparse weak observation",
      () => {
        const sparseWeak =
          activity(
            "sparse-weak",
            10,
            "skill-sparse"
          );

        const establishedWeak =
          activity(
            "established-weak",
            20,
            "skill-established"
          );

        expect(
          resolveNextLearnerActivity({
            activities: [
              sparseWeak,
              establishedWeak
            ],
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            skillProgress: [
              {
                skillId:
                  "skill-sparse",
                masteryScore:
                  0.1,
                observationCount:
                  1,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-established",
                masteryScore:
                  0.25,
                observationCount:
                  2,
                level:
                  "exploring"
              }
            ]
          })?.id
        ).toBe(
          "established-weak"
        );
      }
    );


    it(
      "uses raw need once both skills have sufficient evidence",
      () => {
        const weaker =
          activity(
            "weaker",
            10,
            "skill-weaker"
          );

        const stronger =
          activity(
            "stronger",
            20,
            "skill-stronger"
          );

        expect(
          resolveNextLearnerActivity({
            activities: [
              stronger,
              weaker
            ],
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            skillProgress: [
              {
                skillId:
                  "skill-weaker",
                masteryScore:
                  0.1,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-stronger",
                masteryScore:
                  0.3,
                observationCount:
                  2,
                level:
                  "exploring"
              }
            ]
          })?.id
        ).toBe(
          "weaker"
        );
      }
    );

    it(
      "avoids immediate remediation repetition when learning need is equal",
      () => {
        const first =
          activity(
            "first",
            10,
            "skill-a"
          );

        const second =
          activity(
            "second",
            20,
            "skill-b"
          );

        expect(
          resolveNextLearnerActivity({
            activities: [
              first,
              second
            ],
            completedActivityIds: [
              "first",
              "second"
            ],
            lastCompletedActivityId:
              "first",
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  0.4,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  0.4,
                observationCount:
                  2,
                level:
                  "exploring"
              }
            ]
          })?.id
        ).toBe(
          "second"
        );
      }
    );


    it(
      "does not let diversity override materially greater learning need",
      () => {
        const first =
          activity(
            "first",
            10,
            "skill-a"
          );

        const second =
          activity(
            "second",
            20,
            "skill-b"
          );

        expect(
          resolveNextLearnerActivity({
            activities: [
              first,
              second
            ],
            completedActivityIds: [
              "first",
              "second"
            ],
            lastCompletedActivityId:
              "first",
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  0.1,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  0.6,
                observationCount:
                  2,
                level:
                  "developing"
              }
            ]
          })?.id
        ).toBe(
          "first"
        );
      }
    );


    it(
      "keeps catalogue sequence when previous activity is not a candidate",
      () => {
        const first =
          activity(
            "first",
            10,
            "skill-a"
          );

        const second =
          activity(
            "second",
            20,
            "skill-b"
          );

        expect(
          selectRemediationActivity({
            activities: [
              first,
              second
            ],
            lastCompletedActivityId:
              "outside-catalogue",
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  0.4,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  0.4,
                observationCount:
                  2,
                level:
                  "exploring"
              }
            ]
          })?.id
        ).toBe(
          "first"
        );
      }
    );


    it(
      "keeps unfinished eligible learning ahead of anti-repetition",
      () => {
        const first =
          activity(
            "first",
            10,
            "skill-a"
          );

        const second =
          activity(
            "second",
            20,
            "skill-b"
          );

        expect(
          resolveNextLearnerActivity({
            activities: [
              first,
              second
            ],
            completedActivityIds: [
              "first"
            ],
            lastCompletedActivityId:
              "first",
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  0.1,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  0.9,
                observationCount:
                  2,
                level:
                  "mastered"
              }
            ]
          })?.id
        ).toBe(
          "second"
        );
      }
    );


    it(
      "exposes difficulty fit without changing legacy selection semantics",
      () => {
        const d1 =
          {
            ...activity(
              "d1",
              10,
              "skill-a"
            ),
            difficulty:
              1
          };

        const d2 =
          {
            ...activity(
              "d2",
              20,
              "skill-a"
            ),
            difficulty:
              2
          };

        const sparse = [
          {
            skillId:
              "skill-a",
            masteryScore:
              0.2,
            observationCount:
              1,
            level:
              "exploring" as const
          }
        ];

        expect(
          getActivityDifficultyFit(
            d1,
            sparse
          )
        ).toBeGreaterThan(
          getActivityDifficultyFit(
            d2,
            sparse
          )
        );

        const decision =
          resolveNextLearnerActivityDecision({
            activities:
              [d1, d2],
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            skillProgress:
              sparse
          });

        expect(
          decision?.activity.id
        ).toBe(
          resolveNextLearnerActivity({
            activities:
              [d1, d2],
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            skillProgress:
              sparse
          })?.id
        );
      }
    );
  }
);
