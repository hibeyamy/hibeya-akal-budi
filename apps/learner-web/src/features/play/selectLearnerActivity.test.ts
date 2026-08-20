import {
  describe,
  expect,
  it
} from "vitest";

import {
  selectLearnerActivity
} from "./selectLearnerActivity";


describe(
  "selectLearnerActivity",
  () => {

    it(
      "selects eligible 3-4 content",
      () => {
        const activity =
          selectLearnerActivity({
            ageBand:
              "3-4",

            lastCompletedActivityId:
              null
          });

        expect(activity)
          .not.toBeNull();

        expect(
          activity
            ?.ageBands
            .includes(
              "3-4"
            )
        ).toBe(true);
      }
    );


    it(
      "avoids immediate repetition when alternatives exist",
      () => {
        const first =
          selectLearnerActivity({
            ageBand:
              "3-4",

            lastCompletedActivityId:
              null
          });

        expect(first)
          .not.toBeNull();

        const second =
          selectLearnerActivity({
            ageBand:
              "3-4",

            lastCompletedActivityId:
              first?.id ??
              null
          });

        expect(second)
          .not.toBeNull();

        if (
          first &&
          second
        ) {
          expect(
            second.id
          ).not.toBe(
            first.id
          );
        }
      }
    );


    it(
      "does not serve unsupported content to 2-3",
      () => {
        expect(
          selectLearnerActivity({
            ageBand:
              "2-3",

            lastCompletedActivityId:
              null
          })
        ).toBeNull();
      }
    );

  }
);