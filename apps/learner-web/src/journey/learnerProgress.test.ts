import {
  describe,
  expect,
  it
} from "vitest";

import {
  calculateLearnerProgressPercent
} from "./learnerProgress";

describe(
  "calculateLearnerProgressPercent",
  () => {
    it(
      "returns zero before any completion",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedActivityIds:
              [],
            playableActivityIds:
              ["a", "b"]
          })
        ).toBe(0);
      }
    );

    it(
      "counts replayed activities only once",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedActivityIds:
              ["a", "a"],
            playableActivityIds:
              ["a", "b"]
          })
        ).toBe(50);
      }
    );

    it(
      "ignores completion IDs outside the current playable set",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedActivityIds:
              ["a", "legacy"],
            playableActivityIds:
              ["a", "b"]
          })
        ).toBe(50);
      }
    );

    it(
      "returns one hundred when all playable activities are complete",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedActivityIds:
              ["a", "b", "b"],
            playableActivityIds:
              ["a", "b"]
          })
        ).toBe(100);
      }
    );

    it(
      "returns zero when no playable activities exist",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedActivityIds:
              ["a"],
            playableActivityIds:
              []
          })
        ).toBe(0);
      }
    );
  }
);
