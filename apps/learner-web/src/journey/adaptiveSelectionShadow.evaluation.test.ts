import fs from "node:fs";

import {
  describe,
  expect,
  it
} from "vitest";

import {
  resolveAdaptiveSelectionShadow
} from "./adaptiveSelectionShadow";


type Level =
  | "unobserved"
  | "exploring"
  | "developing"
  | "mastered";


interface MatrixCase {
  skillId:
    string;

  level:
    Level;

  masteryScore:
    number;

  observationCount:
    number;
}


const SKILLS = [
  "colour-recognition",
  "visual-discrimination",
  "early-numeracy"
] as const;


const STATES:
  readonly Omit<
    MatrixCase,
    "skillId"
  >[] = [
    {
      level:
        "unobserved",
      masteryScore:
        0,
      observationCount:
        0
    },
    {
      level:
        "exploring",
      masteryScore:
        0.2,
      observationCount:
        1
    },
    {
      level:
        "exploring",
      masteryScore:
        0.35,
      observationCount:
        2
    },
    {
      level:
        "developing",
      masteryScore:
        0.55,
      observationCount:
        2
    },
    {
      level:
        "developing",
      masteryScore:
        0.7,
      observationCount:
        4
    },
    {
      level:
        "mastered",
      masteryScore:
        0.9,
      observationCount:
        5
    }
  ];


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


function buildActivities(
  skillId:
    string
): any[] {
  return [
    activity(
      `${skillId}-d1-a`,
      10,
      1,
      skillId
    ),
    activity(
      `${skillId}-d1-b`,
      20,
      1,
      skillId
    ),
    activity(
      `${skillId}-d2`,
      30,
      2,
      skillId
    )
  ];
}


function evaluateCase(
  matrixCase:
    MatrixCase,
  completedActivityIds:
    string[] = [],
  lastCompletedActivityId:
    string | null = null
) {
  const activities =
    buildActivities(
      matrixCase.skillId
    );

  const input = {
    activities,
    completedActivityIds,
    lastCompletedActivityId,
    skillProgress: [
      {
        skillId:
          matrixCase.skillId,
        masteryScore:
          matrixCase.masteryScore,
        observationCount:
          matrixCase.observationCount,
        level:
          matrixCase.level
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

  return {
    input,
    first,
    second,
    activities
  };
}


const matrix:
  MatrixCase[] =
  SKILLS.flatMap(
    skillId =>
      STATES.map(
        state => ({
          skillId,
          ...state
        })
      )
  );


describe(
  "adaptive shadow evaluation harness v2.1",
  () => {
    const reportRows:
      Record<
        string,
        unknown
      >[] = [];


    it(
      "evaluates the deterministic learner-state matrix",
      () => {
        for (
          const matrixCase
          of matrix
        ) {
          const {
            first,
            second,
            activities
          } =
            evaluateCase(
              matrixCase
            );

          expect(
            first
          ).not.toBeNull();

          expect(
            second
          ).toEqual(
            first
          );

          const candidate =
            first!;

          expect(
            activities.some(
              activity =>
                activity.id ===
                candidate.adaptiveCandidate.id
            )
          ).toBe(
            true
          );

          const d1Available =
            activities.some(
              activity =>
                activity.difficulty ===
                1
            );

          const sparse =
            matrixCase.observationCount <
              2 ||
            matrixCase.level ===
              "unobserved" ||
            matrixCase.level ===
              "exploring";

          if (
            sparse &&
            d1Available
          ) {
            expect(
              candidate.adaptiveCandidate.difficulty
            ).toBe(
              1
            );
          }

          reportRows.push({
            scenario:
              "base",
            skillId:
              matrixCase.skillId,
            level:
              matrixCase.level,
            masteryScore:
              matrixCase.masteryScore,
            observationCount:
              matrixCase.observationCount,
            authoritativeActivity:
              candidate.authoritativeActivity.id,
            authoritativeDifficulty:
              candidate.authoritativeActivity.difficulty,
            adaptiveCandidate:
              candidate.adaptiveCandidate.id,
            adaptiveDifficulty:
              candidate.adaptiveCandidate.difficulty,
            agrees:
              candidate.agrees,
            learningNeed:
              candidate.learningNeed,
            difficultyFit:
              candidate.difficultyFit,
            adaptiveScore:
              candidate.adaptiveScore
          });
        }
      }
    );


    it(
      "never immediately repeats the last activity when another candidate exists",
      () => {
        for (
          const skillId
          of SKILLS
        ) {
          const matrixCase:
            MatrixCase = {
              skillId,
              level:
                "developing",
              masteryScore:
                0.6,
              observationCount:
                3
            };

          const activities =
            buildActivities(
              skillId
            );

          const lastId =
            activities[2].id;

          const {
            first
          } =
            evaluateCase(
              matrixCase,
              activities.map(
                activity =>
                  activity.id
              ),
              lastId
            );

          expect(
            first
          ).not.toBeNull();

          expect(
            first!.adaptiveCandidate.id
          ).not.toBe(
            lastId
          );

          reportRows.push({
            scenario:
              "repeat-avoidance",
            skillId,
            lastCompletedActivity:
              lastId,
            adaptiveCandidate:
              first!.adaptiveCandidate.id,
            agrees:
              first!.agrees
          });
        }
      }
    );


    it(
      "writes machine-readable evaluation evidence",
      () => {
        const reportPath =
          process.env
            .HIBEYA_SHADOW_EVAL_REPORT;
const baseRows =
          reportRows.filter(
            row =>
              row.scenario ===
              "base"
          );

        const disagreements =
          baseRows.filter(
            row =>
              row.agrees ===
              false
          ).length;

        const agreementRate =
          baseRows.length >
            0
            ? (
                baseRows.length -
                disagreements
              ) /
              baseRows.length
            : 0;

        const prematureD2 =
          baseRows.filter(
            row =>
              (
                Number(
                  row.observationCount
                ) <
                  2 ||
                row.level ===
                  "unobserved" ||
                row.level ===
                  "exploring"
              ) &&
              row.adaptiveDifficulty ===
                2
          );

        const summary = {
          version:
            "2.1",
          activation:
            "none",
          authoritativePolicy:
            "legacy",
          matrixCases:
            baseRows.length,
          skills:
            SKILLS,
          agreementCount:
            baseRows.length -
            disagreements,
          disagreementCount:
            disagreements,
          agreementRate,
          unsafePrematureD2Count:
            prematureD2.length,
          acceptance: {
            deterministic:
              true,
            candidateMustExistInPool:
              true,
            prematureD2Allowed:
              false,
            disagreementRateIsBlocking:
              false
          },
          rows:
            reportRows
        };

                if (
          reportPath
        ) {
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

        expect(
          prematureD2
        ).toHaveLength(
          0
        );
      }
    );
  }
);
