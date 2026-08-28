import {
  describe,
  expect,
  it
} from "vitest";

import {
  selectLearnerActivity
} from "./selectLearnerActivity";


describe(
  "selectLearnerActivity controlled runtime integration",
  () => {
    it(
      "keeps the wired childId path equivalent to legacy while adaptive defaults OFF",
      () => {
        const base = {
          ageBand:
            "3-4" as const,
          lastCompletedActivityId:
            null,
          completedActivityIds:
            [],
          masteredSkillIds:
            [],
          skillProgress:
            []
        };

        const legacy =
          selectLearnerActivity(
            base
          );

        const wired =
          selectLearnerActivity({
            ...base,
            childId:
              "child-stable-test"
          });

        expect(
          wired?.id ??
          null
        ).toBe(
          legacy?.id ??
          null
        );
      }
    );


    it(
      "keeps missing childId on the explicit legacy fail-safe",
      () => {
        const selected =
          selectLearnerActivity({
            ageBand:
              "3-4",
            lastCompletedActivityId:
              null,
            completedActivityIds:
              [],
            masteredSkillIds:
              [],
            skillProgress:
              []
          });

        expect(
          selected
        ).not.toBeNull();
      }
    );
  }
);
