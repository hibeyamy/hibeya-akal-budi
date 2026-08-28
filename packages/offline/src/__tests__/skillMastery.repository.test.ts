import "fake-indexeddb/auto";

import {
  beforeEach,
  describe,
  expect,
  it
} from "vitest";

import {
  clearLearnerSkillMasteryState,
  getLearnerSkillMasteryState,
  saveLearnerSkillMasteryState
} from "../skillMastery.repository";


describe(
  "skill mastery repository",
  () => {
    beforeEach(
      async () => {
        await clearLearnerSkillMasteryState();
      }
    );

    it(
      "returns an empty versioned state initially",
      async () => {
        expect(
          await getLearnerSkillMasteryState()
        ).toEqual({
          version:
            1,
          skills:
            {},
          processedSessionIds:
            [],
          updatedAt:
            0
        });
      }
    );

    it(
      "persists and deduplicates processed session ids",
      async () => {
        await saveLearnerSkillMasteryState({
          version:
            1,
          skills:
            {},
          processedSessionIds: [
            "s1",
            "s1"
          ],
          updatedAt:
            123
        });

        expect(
          (
            await getLearnerSkillMasteryState()
          ).processedSessionIds
        ).toEqual([
          "s1"
        ]);
      }
    );
  }
);
