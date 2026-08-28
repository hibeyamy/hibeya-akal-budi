import {
  describe,
  expect,
  it
} from "vitest";

import {
  isActivityPrerequisiteEligible
} from "../eligibility";

import type {
  ResolvedPlayableActivity
} from "../catalogue";


function activity(
  requiredPrerequisiteSkillIds:
    readonly string[]
): ResolvedPlayableActivity {
  return {
    requiredPrerequisiteSkillIds
  } as ResolvedPlayableActivity;
}


describe(
  "prerequisite eligibility",
  () => {
    it(
      "allows an activity with no required prerequisites",
      () => {
        expect(
          isActivityPrerequisiteEligible(
            activity([]),
            new Set()
          )
        ).toBe(true);
      }
    );

    it(
      "blocks until all required skills are mastered",
      () => {
        expect(
          isActivityPrerequisiteEligible(
            activity([
              "a",
              "b"
            ]),
            new Set([
              "a"
            ])
          )
        ).toBe(false);
      }
    );

    it(
      "unlocks when every required skill is mastered",
      () => {
        expect(
          isActivityPrerequisiteEligible(
            activity([
              "a",
              "b"
            ]),
            new Set([
              "a",
              "b"
            ])
          )
        ).toBe(true);
      }
    );
  }
);
