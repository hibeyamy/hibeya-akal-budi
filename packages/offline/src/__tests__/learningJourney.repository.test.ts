import "fake-indexeddb/auto";

import {
  beforeEach,
  describe,
  expect,
  it
} from "vitest";

import {
  resetDatabaseForTests
} from "../database";

import {
  clearLearnerJourneyState,
  getLearnerJourneyState,
  recordCompletedJourneyActivity
} from "../learningJourney.repository";


describe(
  "learner journey repository",
  () => {

    beforeEach(
      async () => {
        await resetDatabaseForTests();
      }
    );

    it(
      "starts empty",
      async () => {
        expect(
          await getLearnerJourneyState()
        ).toEqual({
          lastCompletedActivityId:
            null,

          completedSessionCount:
            0,

          updatedAt:
            0
        });
      }
    );

    it(
      "records completion",
      async () => {
        const state =
          await recordCompletedJourneyActivity(
            "warna-bunga-raya-001"
          );

        expect(
          state.lastCompletedActivityId
        ).toBe(
          "warna-bunga-raya-001"
        );

        expect(
          state.completedSessionCount
        ).toBe(1);
      }
    );

    it(
      "clears state",
      async () => {
        await recordCompletedJourneyActivity(
          "warna-bunga-raya-001"
        );

        await clearLearnerJourneyState();

        expect(
          await getLearnerJourneyState()
        ).toEqual({
          lastCompletedActivityId:
            null,

          completedSessionCount:
            0,

          updatedAt:
            0
        });
      }
    );

  }
);