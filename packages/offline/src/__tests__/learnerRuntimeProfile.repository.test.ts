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
  clearLearnerRuntimeProfile,
  getCachedLearnerRuntimeProfile,
  saveLearnerRuntimeProfile
} from "../learnerRuntimeProfile.repository";


describe(
  "learner runtime profile cache",
  () => {

    beforeEach(
      async () => {
        await resetDatabaseForTests();
      }
    );

    it(
      "stores and retrieves the minimal profile",
      async () => {
        await saveLearnerRuntimeProfile({
          childId:
            "child-123",

          ageBand:
            "3-4",

          preferredLanguage:
            "ms",

          validatedAt:
            123456
        });

        expect(
          await getCachedLearnerRuntimeProfile()
        ).toEqual({
          childId:
            "child-123",

          ageBand:
            "3-4",

          preferredLanguage:
            "ms",

          validatedAt:
            123456
        });
      }
    );

    it(
      "clears the profile",
      async () => {
        await saveLearnerRuntimeProfile({
          childId:
            "child-123",

          ageBand:
            "3-4",

          preferredLanguage:
            "ms",

          validatedAt:
            123456
        });

        await clearLearnerRuntimeProfile();

        expect(
          await getCachedLearnerRuntimeProfile()
        ).toBeNull();
      }
    );

  }
);