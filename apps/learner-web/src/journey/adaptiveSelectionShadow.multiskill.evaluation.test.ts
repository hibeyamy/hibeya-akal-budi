import fs from "node:fs";

import {
  describe,
  expect,
  it
} from "vitest";

import {
  resolveAdaptiveSelectionShadow
} from "./adaptiveSelectionShadow";

import {
  getActivityLearningNeed
} from "./nextLearnerActivity.service";


type Level =
  | "unobserved"
  | "exploring"
  | "developing"
  | "mastered";


interface SkillState {
  skillId:
    string;

  masteryScore:
    number;

  observationCount:
    number;

  level:
    Level;
}


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
    supportingSkillIds:
      [],
    requiredPrerequisiteSkillIds:
      [],
    ageBands:
      ["3-4"],
    titleMs:
      id,
    titleEn:
      id,
    blueprintId:
      "evaluation",
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


function run(
  skillProgress:
    SkillState[],
  completedActivityIds:
    string[] = [],
  lastCompletedActivityId:
    string | null = null
) {
  return resolveAdaptiveSelectionShadow({
    activities,
    completedActivityIds,
    lastCompletedActivityId,
    skillProgress
  } as any);
}


describe(
  "adaptive shadow evaluation v2.2 - multi-skill learning need",
  () => {
    const rows:
      Record<
        string,
        unknown
      >[] = [];


    it(
      "proves production learning need discriminates and drives selection when difficulty fit is equal",
      () => {
        const skillProgress:
          SkillState[] = [
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
                0.15,
              observationCount:
                3,
              level:
                "exploring"
            },
            {
              skillId:
                "early-numeracy",
              masteryScore:
                0.75,
              observationCount:
                4,
              level:
                "developing"
            }
          ];

        const d1Activities =
          activities.filter(
            item =>
              item.difficulty ===
              1
          );

        const scored =
          d1Activities
            .map(
              item => ({
                item,
                need:
                  getActivityLearningNeed(
                    item,
                    skillProgress as any
                  )
              })
            )
            .sort(
              (
                left,
                right
              ) =>
                right.need -
                left.need ||
                left.item.sequence -
                right.item.sequence ||
                left.item.id.localeCompare(
                  right.item.id
                )
            );

        const distinctNeeds =
          new Set(
            scored.map(
              entry =>
                entry.need.toFixed(
                  8
                )
            )
          );

        expect(
          distinctNeeds.size
        ).toBeGreaterThan(
          1
        );

        const decision =
          resolveAdaptiveSelectionShadow({
            activities:
              d1Activities,
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            skillProgress
          } as any);

        expect(
          decision
        ).not.toBeNull();

        expect(
          decision!.adaptiveCandidate.id
        ).toBe(
          scored[0].item.id
        );

        rows.push({
          scenario:
            "learning-need-discrimination",
          adaptiveCandidate:
            decision!.adaptiveCandidate.id,
          adaptiveSkill:
            decision!.adaptiveCandidate.primarySkillIds[0],
          highestProductionLearningNeed:
            scored[0].need,
          lowestProductionLearningNeed:
            scored[
              scored.length -
              1
            ].need,
          learningNeedSpread:
            scored[0].need -
            scored[
              scored.length -
              1
            ].need,
          productionScores:
            scored.map(
              entry => ({
                activityId:
                  entry.item.id,
                skillId:
                  entry.item.primarySkillIds[0],
                learningNeed:
                  entry.need
              })
            )
        });
      }
    );


    it(
      "allows a stronger observed skill to move to D2 when learning-need differences are small",
      () => {
        const decision =
          run([
            {
              skillId:
                "colour-recognition",
              masteryScore:
                0.55,
              observationCount:
                3,
              level:
                "developing"
            },
            {
              skillId:
                "visual-discrimination",
              masteryScore:
                0.5,
              observationCount:
                3,
              level:
                "developing"
            },
            {
              skillId:
                "early-numeracy",
              masteryScore:
                0.52,
              observationCount:
                3,
              level:
                "developing"
            }
          ]);

        expect(
          decision
        ).not.toBeNull();

        expect(
          decision!.adaptiveCandidate.difficulty
        ).toBe(
          2
        );

        rows.push({
          scenario:
            "balanced-developing-d2",
          adaptiveCandidate:
            decision!.adaptiveCandidate.id,
          adaptiveSkill:
            decision!.adaptiveCandidate.primarySkillIds[0],
          learningNeed:
            decision!.learningNeed,
          difficultyFit:
            decision!.difficultyFit,
          adaptiveScore:
            decision!.adaptiveScore
        });
      }
    );


    it(
      "keeps sparse evidence conservative even when mastery score is numerically high",
      () => {
        const decision =
          run([
            {
              skillId:
                "colour-recognition",
              masteryScore:
                0.9,
              observationCount:
                1,
              level:
                "exploring"
            },
            {
              skillId:
                "visual-discrimination",
              masteryScore:
                0.7,
              observationCount:
                4,
              level:
                "developing"
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
          ]);

        expect(
          decision
        ).not.toBeNull();

        if(
          decision!.adaptiveCandidate.primarySkillIds[0] ===
          "colour-recognition"
        ){
          expect(
            decision!.adaptiveCandidate.difficulty
          ).toBe(
            1
          );
        }

        rows.push({
          scenario:
            "sparse-confidence-conservative",
          adaptiveCandidate:
            decision!.adaptiveCandidate.id,
          adaptiveSkill:
            decision!.adaptiveCandidate.primarySkillIds[0],
          adaptiveDifficulty:
            decision!.adaptiveCandidate.difficulty
        });
      }
    );


    it(
      "respects completion state and excludes completed activities while uncompleted candidates remain",
      () => {
        const decision =
          run(
            [
              {
                skillId:
                  "colour-recognition",
                masteryScore:
                  0.4,
                observationCount:
                  3,
                level:
                  "developing"
              },
              {
                skillId:
                  "visual-discrimination",
                masteryScore:
                  0.4,
                observationCount:
                  3,
                level:
                  "developing"
              },
              {
                skillId:
                  "early-numeracy",
                masteryScore:
                  0.4,
                observationCount:
                  3,
                level:
                  "developing"
              }
            ],
            [
              "colour-d1",
              "visual-d1",
              "numeracy-d1"
            ]
          );

        expect(
          decision
        ).not.toBeNull();

        expect(
          [
            "colour-d2",
            "visual-d2",
            "numeracy-d2"
          ]
        ).toContain(
          decision!.adaptiveCandidate.id
        );

        rows.push({
          scenario:
            "completion-filter",
          adaptiveCandidate:
            decision!.adaptiveCandidate.id
        });
      }
    );


    it(
      "retains repeat avoidance during full-cycle remediation conditions",
      () => {
        const decision =
          run(
            [
              {
                skillId:
                  "colour-recognition",
                masteryScore:
                  0.2,
                observationCount:
                  4,
                level:
                  "exploring"
              },
              {
                skillId:
                  "visual-discrimination",
                masteryScore:
                  0.7,
                observationCount:
                  4,
                level:
                  "developing"
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
            ],
            activities.map(
              item =>
                item.id
            ),
            "colour-d1"
          );

        expect(
          decision
        ).not.toBeNull();

        expect(
          decision!.adaptiveCandidate.id
        ).not.toBe(
          "colour-d1"
        );

        rows.push({
          scenario:
            "full-cycle-repeat-avoidance",
          adaptiveCandidate:
            decision!.adaptiveCandidate.id,
          lastCompleted:
            "colour-d1"
        });
      }
    );


    it(
      "is deterministic under exact scoring ties",
      () => {
        const skillProgress:
          SkillState[] = [
            {
              skillId:
                "colour-recognition",
              masteryScore:
                0.5,
              observationCount:
                3,
              level:
                "developing"
            },
            {
              skillId:
                "visual-discrimination",
              masteryScore:
                0.5,
              observationCount:
                3,
              level:
                "developing"
            },
            {
              skillId:
                "early-numeracy",
              masteryScore:
                0.5,
              observationCount:
                3,
              level:
                "developing"
            }
          ];

        const first =
          run(
            skillProgress
          );

        const second =
          run(
            skillProgress
          );

        expect(
          first
        ).toEqual(
          second
        );

        rows.push({
          scenario:
            "deterministic-tie",
          adaptiveCandidate:
            first?.adaptiveCandidate.id
        });
      }
    );


    it(
      "writes multi-skill evaluation evidence when requested",
      () => {
        const reportPath =
          process.env
            .HIBEYA_SHADOW_EVAL_V22_REPORT;

        const summary = {
          version:
            "2.2",
          activation:
            "none",
          authoritativePolicy:
            "legacy",
          scenarios:
            rows.length,
          safety: {
            learningNeedDiscriminationObserved:
              rows.some(
                row =>
                  row.scenario ===
                    "learning-need-discrimination" &&
                  Number(
                    row.learningNeedSpread
                  ) >
                    0
              ),
            completionFilterObserved:
              rows.some(
                row =>
                  row.scenario ===
                    "completion-filter"
              ),
            repeatAvoidanceObserved:
              rows.some(
                row =>
                  row.scenario ===
                    "full-cycle-repeat-avoidance"
              ),
            deterministicTieObserved:
              rows.some(
                row =>
                  row.scenario ===
                    "deterministic-tie"
              )
          },
          rows
        };

        expect(
          summary.safety.learningNeedDiscriminationObserved
        ).toBe(
          true
        );

        expect(
          summary.safety.completionFilterObserved
        ).toBe(
          true
        );

        expect(
          summary.safety.repeatAvoidanceObserved
        ).toBe(
          true
        );

        expect(
          summary.safety.deterministicTieObserved
        ).toBe(
          true
        );

        if(
          reportPath
        ){
          fs.writeFileSync(
            reportPath,
            JSON.stringify(
              summary,
              null,
              2
            ) +
              "\n",
            "utf8"
          );
        }
      }
    );
  }
);
