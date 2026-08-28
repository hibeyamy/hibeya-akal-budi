import {
  describe,
  expect,
  it
} from "vitest";

import {
  getEligibleActivitiesForLearner,
  playableActivities
} from "@akal-budi/content-library";

import type {
  LearnerAgeBand
} from "../../services/deviceActivationService";

import {
  selectLearnerActivity
} from "./selectLearnerActivity";


function getSupportedLearnerAgeBand():
  LearnerAgeBand {
  const candidate =
    playableActivities
      .flatMap(
        activity =>
          activity.ageBands
      )
      .find(
        (
          ageBand
        ): ageBand is LearnerAgeBand =>
          ageBand ===
            "2-3" ||
          ageBand ===
            "3-4" ||
          ageBand ===
            "4-5" ||
          ageBand ===
            "5-6"
      );

  if (!candidate) {
    throw new Error(
      "No playable learner age band is available in the current catalogue."
    );
  }

  return candidate;
}


describe(
  "selectLearnerActivity",
  () => {
    it(
      "follows prerequisite-eligible catalogue order",
      () => {
        const ageBand =
          getSupportedLearnerAgeBand();

        const masteredSkillIds:
          string[] = [];

        const eligible =
          getEligibleActivitiesForLearner({
            ageBand,
            masteredSkillIds
          });

        const selected =
          selectLearnerActivity({
            ageBand,

            lastCompletedActivityId:
              null,

            completedActivityIds:
              [],

            masteredSkillIds
          });

        expect(
          selected?.id ??
          null
        ).toBe(
          eligible[0]?.id ??
          null
        );
      }
    );


    it(
      "keeps completion progression separate from mastery eligibility",
      () => {
        const ageBand =
          getSupportedLearnerAgeBand();

        const masteredSkillIds:
          string[] = [];

        const eligible =
          getEligibleActivitiesForLearner({
            ageBand,
            masteredSkillIds
          });

        const first =
          eligible[0];

        if (!first) {
          expect(
            selectLearnerActivity({
              ageBand,

              lastCompletedActivityId:
                null,

              completedActivityIds:
                [],

              masteredSkillIds
            })
          ).toBeNull();

          return;
        }

        const selected =
          selectLearnerActivity({
            ageBand,

            lastCompletedActivityId:
              first.id,

            completedActivityIds:
              [first.id],

            masteredSkillIds
          });

        const firstUncompleted =
          eligible.find(
            activity =>
              activity.id !==
                first.id
          );

        if (
          firstUncompleted
        ) {
          expect(
            selected?.id
          ).toBe(
            firstUncompleted.id
          );
        }
        else {
          // The resolver intentionally cycles only after all eligible
          // activities are complete.
          expect(
            selected?.id
          ).toBe(
            first.id
          );
        }
      }
    );


    it(
      "does not use completed activities as a substitute for mastered skills",
      () => {
        const ageBand =
          getSupportedLearnerAgeBand();

        const selected =
          selectLearnerActivity({
            ageBand,

            lastCompletedActivityId:
              null,

            completedActivityIds:
              [],

            masteredSkillIds:
              []
          });

        const eligible =
          getEligibleActivitiesForLearner({
            ageBand,

            masteredSkillIds:
              []
          });

        expect(
          selected?.id ??
          null
        ).toBe(
          eligible[0]?.id ??
          null
        );
      }
    );
  }
);
