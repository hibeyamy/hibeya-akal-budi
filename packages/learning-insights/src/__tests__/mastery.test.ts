import {
  describe,
  expect,
  it
} from "vitest";

import {
  applySkillMasteryEvidence,
  createEmptySkillMasteryState,
  getMasteredSkillIds
} from "../mastery";


const mappings = [
  {
    skillId:
      "colour-recognition",

    role:
      "primary" as const,

    weight:
      1
  },
  {
    skillId:
      "visual-discrimination",

    role:
      "supporting" as const,

    weight:
      0.5
  }
];


function evidence(
  sessionId: string,
  correct: number,
  incorrect: number
) {
  return {
    sessionId,
    activityId:
      "activity-a",
    completedAt:
      1000,
    correct,
    incorrect,
    attempts:
      correct + incorrect,
    durationSeconds:
      10,
    skillMappings:
      mappings
  };
}


describe(
  "skill mastery",
  () => {
    it(
      "does not master a skill from a single successful observation",
      () => {
        const state =
          applySkillMasteryEvidence(
            createEmptySkillMasteryState(),
            evidence(
              "s1",
              1,
              0
            )
          );

        expect(
          state.skills[
            "colour-recognition"
          ]?.level
        ).toBe(
          "developing"
        );
      }
    );

    it(
      "masters after repeated sufficiently strong evidence",
      () => {
        const first =
          applySkillMasteryEvidence(
            createEmptySkillMasteryState(),
            evidence(
              "s1",
              1,
              0
            )
          );

        const second =
          applySkillMasteryEvidence(
            first,
            evidence(
              "s2",
              1,
              0
            )
          );

        expect(
          getMasteredSkillIds(
            second
          )
        ).toContain(
          "colour-recognition"
        );
      }
    );

    it(
      "does not double count the same session",
      () => {
        const first =
          applySkillMasteryEvidence(
            createEmptySkillMasteryState(),
            evidence(
              "s1",
              1,
              0
            )
          );

        const duplicate =
          applySkillMasteryEvidence(
            first,
            evidence(
              "s1",
              1,
              0
            )
          );

        expect(
          duplicate
        ).toEqual(
          first
        );
      }
    );

    it(
      "keeps mixed evidence below mastery threshold",
      () => {
        const first =
          applySkillMasteryEvidence(
            createEmptySkillMasteryState(),
            evidence(
              "s1",
              1,
              1
            )
          );

        const second =
          applySkillMasteryEvidence(
            first,
            evidence(
              "s2",
              1,
              1
            )
          );

        expect(
          second.skills[
            "colour-recognition"
          ]?.level
        ).not.toBe(
          "mastered"
        );
      }
    );
  }
);
