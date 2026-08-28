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

          completedActivityIds:
            [],

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

        expect(
          state.completedActivityIds
        ).toEqual([
          "warna-bunga-raya-001"
        ]);
      }
    );
    it(
      "does not duplicate unique completion when an activity is replayed",
      async () => {
        await recordCompletedJourneyActivity(
          "warna-bunga-raya-001"
        );

        const state =
          await recordCompletedJourneyActivity(
            "warna-bunga-raya-001"
          );

        expect(
          state.completedSessionCount
        ).toBe(2);

        expect(
          state.completedActivityIds
        ).toEqual([
          "warna-bunga-raya-001"
        ]);
      }
    );


    it(
      "tracks distinct completed activities",
      async () => {
        await recordCompletedJourneyActivity(
          "warna-bunga-raya-001"
        );

        const state =
          await recordCompletedJourneyActivity(
            "warna-merah-001"
          );

        expect(
          state.completedSessionCount
        ).toBe(2);

        expect(
          state.completedActivityIds
        ).toEqual([
          "warna-bunga-raya-001",
          "warna-merah-001"
        ]);
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

          completedActivityIds:
            [],

          updatedAt:
            0
        });
      }
    );


    it(
      "does not double-count the same completed session",
      async () => {
        await recordCompletedJourneyActivity(
          "warna-merah-001",
          "session-abc"
        );

        const state =
          await recordCompletedJourneyActivity(
            "warna-merah-001",
            "session-abc"
          );

        expect(
          state.completedSessionCount
        ).toBe(1);

        expect(
          state.completedActivityIds
        ).toEqual([
          "warna-merah-001"
        ]);
      }
    );

  }
);
