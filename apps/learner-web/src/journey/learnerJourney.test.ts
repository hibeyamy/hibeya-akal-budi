import {
  describe,
  expect,
  it
} from "vitest";

import {
  initialLearnerJourneyState,
  learnerJourneyReducer
} from "./learnerJourney";

describe(
  "learnerJourneyReducer",
  () => {
    it(
      "opens an activity from home and returns home",
      () => {
        const opened =
          learnerJourneyReducer(
            initialLearnerJourneyState,
            {
              type:
                "OPEN_ACTIVITY",

              activityId:
                "warna-merah-001",

              from:
                "home"
            }
          );

        expect(
          opened
        ).toEqual({
          view:
            "activity",

          activeActivityId:
            "warna-merah-001",

          previousView:
            "home"
        });

        expect(
          learnerJourneyReducer(
            opened,
            {
              type:
                "CLOSE_ACTIVITY"
            }
          )
        ).toEqual(
          initialLearnerJourneyState
        );
      }
    );

    it(
      "returns to explore after an activity opened from explore",
      () => {
        const explore =
          learnerJourneyReducer(
            initialLearnerJourneyState,
            {
              type:
                "GO_EXPLORE"
            }
          );

        const opened =
          learnerJourneyReducer(
            explore,
            {
              type:
                "OPEN_ACTIVITY",

              activityId:
                "warna-bunga-raya-001",

              from:
                "explore"
            }
          );

        const closed =
          learnerJourneyReducer(
            opened,
            {
              type:
                "CLOSE_ACTIVITY"
            }
          );

        expect(
          closed.view
        ).toBe(
          "explore"
        );

        expect(
          closed.activeActivityId
        ).toBeNull();
      }
    );
  }
);
