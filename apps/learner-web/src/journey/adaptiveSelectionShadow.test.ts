import {
  describe,
  expect,
  it
} from "vitest";

import {
  resolveAdaptiveSelectionShadow
} from "./adaptiveSelectionShadow";


function activity(
  id:
    string,
  sequence:
    number,
  difficulty:
    number
): any {
  return {
    id,
    sequence,
    difficulty,
    skillIds:
      ["skill-a"],
    primarySkillIds:
      ["skill-a"],
    supportingSkillIds:
      [],
    ageBands:
      ["3-4"],
    titleMs:
      id,
    titleEn:
      id,
    blueprintId:
      "test",
    implementationKey:
      "colour-choice-v1"
  };
}


describe(
  "adaptive selection shadow mode",
  () => {
    it(
      "keeps legacy selection authoritative when shadow agrees",
      () => {
        const decision =
          resolveAdaptiveSelectionShadow({
            activities: [
              activity(
                "d1",
                10,
                1
              ),
              activity(
                "d2",
                20,
                2
              )
            ],
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            skillProgress:
              []
          } as any);

        expect(
          decision?.authoritativeActivity.id
        ).toBe(
          "d1"
        );

        expect(
          decision?.adaptiveCandidate.id
        ).toBe(
          "d1"
        );

        expect(
          decision?.agrees
        ).toBe(
          true
        );
      }
    );


    it(
      "records disagreement without activating the adaptive candidate",
      () => {
        const decision =
          resolveAdaptiveSelectionShadow({
            activities: [
              activity(
                "d1",
                10,
                1
              ),
              activity(
                "d2",
                20,
                2
              )
            ],
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  0.6,
                observationCount:
                  2,
                level:
                  "developing"
              }
            ]
          } as any);

        expect(
          decision?.authoritativeActivity.id
        ).toBe(
          "d1"
        );

        expect(
          decision?.adaptiveCandidate.id
        ).toBe(
          "d2"
        );

        expect(
          decision?.agrees
        ).toBe(
          false
        );

        expect(
          decision?.adaptiveReason
        ).toBe(
          "shadow-score"
        );
      }
    );


    it(
      "is deterministic for identical learner state",
      () => {
        const input = {
          activities: [
            activity(
              "a",
              10,
              1
            ),
            activity(
              "b",
              20,
              1
            )
          ],
          completedActivityIds:
            [],
          lastCompletedActivityId:
            null,
          skillProgress:
            []
        } as any;

        expect(
          resolveAdaptiveSelectionShadow(
            input
          )
        ).toEqual(
          resolveAdaptiveSelectionShadow(
            input
          )
        );
      }
    );


    it(
      "avoids immediately repeating the last activity when another shadow candidate exists",
      () => {
        const decision =
          resolveAdaptiveSelectionShadow({
            activities: [
              activity(
                "a",
                10,
                1
              ),
              activity(
                "b",
                20,
                1
              )
            ],
            completedActivityIds:
              ["a","b"],
            lastCompletedActivityId:
              "a",
            skillProgress:
              []
          } as any);

        expect(
          decision?.adaptiveCandidate.id
        ).toBe(
          "b"
        );
      }
    );
  }
);
