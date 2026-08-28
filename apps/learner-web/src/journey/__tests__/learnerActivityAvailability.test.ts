import {
  describe,
  expect,
  it
} from "vitest";

import {
  getLearnerActivitiesForAgeBand,
  hasLearnerContentForAgeBand
} from "../learnerActivityAvailability";

describe(
  "learner age-band activity boundary",
  () => {
    it(
      "does not fall back to 3-4 content for a 2-3 learner",
      () => {
        expect(
          getLearnerActivitiesForAgeBand(
            "2-3"
          )
        ).toEqual([]);

        expect(
          hasLearnerContentForAgeBand(
            "2-3"
          )
        ).toBe(false);
      }
    );

    it(
      "keeps the approved 3-4 catalogue available",
      () => {
        const activities =
          getLearnerActivitiesForAgeBand(
            "3-4"
          );

        expect(
          activities.length
        ).toBeGreaterThan(0);

        expect(
          activities.every(
            activity =>
              activity.ageBands.includes(
                "3-4"
              )
          )
        ).toBe(true);
      }
    );
  }
);
