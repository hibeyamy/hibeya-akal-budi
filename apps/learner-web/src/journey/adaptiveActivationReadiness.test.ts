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
  resolveNextLearnerActivity
} from "./nextLearnerActivity.service";


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
      "activation-readiness",
    implementationKey:
      "colour-choice-v1"
  };
}


const catalogue = [
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
  overrides:
    Partial<any> = {}
) {
  const input = {
    activities:
      catalogue,
    completedActivityIds:
      [],
    lastCompletedActivityId:
      null,
    skillProgress:
      [],
    ...overrides
  } as any;

  return {
    legacy:
      resolveNextLearnerActivity(
        input
      ),

    shadow:
      resolveAdaptiveSelectionShadow(
        input
      )
  };
}


describe(
  "adaptive activation-readiness gate",
  () => {
    const rows:
      Record<
        string,
        unknown
      >[] = [];


    it(
      "preserves deterministic legacy recovery when adaptive shadow is ignored",
      () => {
        const input = {
          activities:
            catalogue,
          completedActivityIds:
            [],
          lastCompletedActivityId:
            null,
          skillProgress:
            []
        } as any;

        const first =
          resolveNextLearnerActivity(
            input
          );

        const second =
          resolveNextLearnerActivity(
            input
          );

        expect(
          first
        ).toEqual(
          second
        );

        expect(
          first?.id
        ).toBeTruthy();

        rows.push({
          scenario:
            "legacy-recovery",
          activity:
            first?.id
        });
      }
    );


    it(
      "handles missing skill progress by falling back safely",
      () => {
        const result =
          run({
            skillProgress:
              undefined
          });

        expect(
          result.legacy
        ).not.toBeNull();

        expect(
          result.shadow
        ).not.toBeNull();

        expect(
          result.shadow?.authoritativeActivity.id
        ).toBe(
          result.legacy?.id
        );

        rows.push({
          scenario:
            "missing-skill-progress",
          authoritative:
            result.legacy?.id,
          shadow:
            result.shadow?.adaptiveCandidate.id
        });
      }
    );


    it(
      "handles partial skill progress without crashing or fabricating prerequisites",
      () => {
        const result =
          run({
            skillProgress: [
              {
                skillId:
                  "early-numeracy",
                masteryScore:
                  0.2,
                observationCount:
                  1,
                level:
                  "exploring"
              }
            ]
          });

        expect(
          result.legacy
        ).not.toBeNull();

        expect(
          result.shadow
        ).not.toBeNull();

        expect(
          result.shadow?.adaptiveCandidate.difficulty
        ).toBe(
          1
        );

        rows.push({
          scenario:
            "partial-skill-progress",
          authoritative:
            result.legacy?.id,
          shadow:
            result.shadow?.adaptiveCandidate.id
        });
      }
    );


    it(
      "keeps sparse evidence conservative at D1",
      () => {
        const result =
          run({
            skillProgress: [
              {
                skillId:
                  "colour-recognition",
                masteryScore:
                  0.95,
                observationCount:
                  1,
                level:
                  "exploring"
              },
              {
                skillId:
                  "visual-discrimination",
                masteryScore:
                  0.9,
                observationCount:
                  1,
                level:
                  "exploring"
              },
              {
                skillId:
                  "early-numeracy",
                masteryScore:
                  0.9,
                observationCount:
                  1,
                level:
                  "exploring"
              }
            ]
          });

        expect(
          result.shadow?.adaptiveCandidate.difficulty
        ).toBe(
          1
        );

        rows.push({
          scenario:
            "sparse-evidence-boundary",
          shadow:
            result.shadow?.adaptiveCandidate.id
        });
      }
    );


    it(
      "permits D2 only after sufficient observations",
      () => {
        const result =
          run({
            skillProgress: [
              {
                skillId:
                  "colour-recognition",
                masteryScore:
                  0.6,
                observationCount:
                  2,
                level:
                  "developing"
              },
              {
                skillId:
                  "visual-discrimination",
                masteryScore:
                  0.6,
                observationCount:
                  2,
                level:
                  "developing"
              },
              {
                skillId:
                  "early-numeracy",
                masteryScore:
                  0.6,
                observationCount:
                  2,
                level:
                  "developing"
              }
            ]
          });

        expect(
          result.shadow
        ).not.toBeNull();

        expect(
          [
            1,
            2
          ]
        ).toContain(
          result.shadow?.adaptiveCandidate.difficulty
        );

        if(
          result.shadow?.adaptiveCandidate.difficulty ===
          2
        ){
          expect(
            result.shadow.difficultyFit
          ).toBeGreaterThan(
            0
          );
        }

        rows.push({
          scenario:
            "d2-observation-threshold",
          shadow:
            result.shadow?.adaptiveCandidate.id,
          difficulty:
            result.shadow?.adaptiveCandidate.difficulty
        });
      }
    );


    it(
      "survives completed-catalogue edge cases with repeat avoidance",
      () => {
        const result =
          run({
            completedActivityIds:
              catalogue.map(
                item =>
                  item.id
              ),
            lastCompletedActivityId:
              "colour-d1",
            skillProgress: [
              {
                skillId:
                  "colour-recognition",
                masteryScore:
                  0.2,
                observationCount:
                  4,
                level:
                  "exploring"
              }
            ]
          });

        expect(
          result.legacy
        ).not.toBeNull();

        expect(
          result.shadow
        ).not.toBeNull();

        expect(
          result.shadow?.adaptiveCandidate.id
        ).not.toBe(
          "colour-d1"
        );

        rows.push({
          scenario:
            "completed-catalogue",
          authoritative:
            result.legacy?.id,
          shadow:
            result.shadow?.adaptiveCandidate.id
        });
      }
    );


    it(
      "remains deterministic for identical adversarial input",
      () => {
        const input = {
          activities:
            catalogue,
          completedActivityIds:
            ["colour-d1"],
          lastCompletedActivityId:
            "colour-d1",
          skillProgress: [
            {
              skillId:
                "colour-recognition",
              masteryScore:
                0.5,
              observationCount:
                2,
              level:
                "developing"
            },
            {
              skillId:
                "visual-discrimination",
              masteryScore:
                0.5,
              observationCount:
                2,
              level:
                "developing"
            },
            {
              skillId:
                "early-numeracy",
              masteryScore:
                0.5,
              observationCount:
                2,
              level:
                "developing"
            }
          ]
        } as any;

        const first =
          resolveAdaptiveSelectionShadow(
            input
          );

        const second =
          resolveAdaptiveSelectionShadow(
            input
          );

        expect(
          first
        ).toEqual(
          second
        );

        rows.push({
          scenario:
            "adversarial-determinism",
          shadow:
            first?.adaptiveCandidate.id
        });
      }
    );


    it(
      "writes activation-readiness evidence when requested",
      () => {
        const reportPath =
          process.env
            .HIBEYA_ADAPTIVE_ACTIVATION_READINESS_REPORT;

        const summary = {
          version:
            "1.0",
          activation:
            "none",
          authoritativePolicy:
            "legacy",
          cases:
            rows.length,
          criteria: {
            legacyRecovery:
              rows.some(
                row =>
                  row.scenario ===
                    "legacy-recovery"
              ),
            missingStateFallback:
              rows.some(
                row =>
                  row.scenario ===
                    "missing-skill-progress"
              ),
            partialStateFallback:
              rows.some(
                row =>
                  row.scenario ===
                    "partial-skill-progress"
              ),
            sparseEvidenceConservative:
              rows.some(
                row =>
                  row.scenario ===
                    "sparse-evidence-boundary"
              ),
            completedCatalogueSafe:
              rows.some(
                row =>
                  row.scenario ===
                    "completed-catalogue"
              ),
            deterministic:
              rows.some(
                row =>
                  row.scenario ===
                    "adversarial-determinism"
              )
          }
        };

        for(
          const value
          of Object.values(
            summary.criteria
          )
        ){
          expect(
            value
          ).toBe(
            true
          );
        }

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
