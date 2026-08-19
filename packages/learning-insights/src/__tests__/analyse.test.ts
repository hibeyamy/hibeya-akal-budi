import {
  describe,
  expect,
  it
} from "vitest";

import {
  analyseLearningSessions
} from "../analyse";


const now =
  new Date(
    "2026-08-20T12:00:00.000Z"
  );


describe(
  "analyseLearningSessions",
  () => {

    it(
      "returns an empty summary when there are no sessions",
      () => {
        const result =
          analyseLearningSessions(
            [],
            now
          );


        expect(
          result.totalSessions
        ).toBe(0);

        expect(
          result.totalLearningMinutes
        ).toBe(0);

        expect(
          result.objectives
        ).toEqual([]);
      }
    );


    it(
      "maps a known activity to its learning objectives",
      () => {
        const result =
          analyseLearningSessions(
            [
              {
                activityId:
                  "warna-merah-001",

                completedAt:
                  "2026-08-20T10:00:00.000Z",

                correctCount:
                  2,

                incorrectCount:
                  1,

                attempts:
                  3,

                durationSeconds:
                  60
              }
            ],
            now
          );


        expect(
          result.objectives
            .map(
              item =>
                item.objectiveId
            )
            .sort()
        ).toEqual(
          [
            "colour-recognition",
            "malay-vocabulary",
            "visual-matching"
          ].sort()
        );
      }
    );


    it(
      "does not invent learning observations for unknown activities",
      () => {
        const result =
          analyseLearningSessions(
            [
              {
                activityId:
                  "unknown-activity",

                completedAt:
                  "2026-08-20T10:00:00.000Z",

                correctCount:
                  10,

                incorrectCount:
                  0,

                attempts:
                  10,

                durationSeconds:
                  120
              }
            ],
            now
          );


        expect(
          result.totalSessions
        ).toBe(1);

        expect(
          result.objectives
        ).toEqual([]);
      }
    );


    it(
      "starts a new learning objective as exploring",
      () => {
        const result =
          analyseLearningSessions(
            [
              {
                activityId:
                  "warna-merah-001",

                completedAt:
                  "2026-08-20T10:00:00.000Z",

                correctCount:
                  3,

                incorrectCount:
                  0,

                attempts:
                  3,

                durationSeconds:
                  60
              }
            ],
            now
          );


        expect(
          result.objectives[0]
            ?.signal
        ).toBe(
          "exploring"
        );
      }
    );


    it(
      "requires repeated exposure before showing confidence",
      () => {
        const sessions =
          Array.from(
            {
              length: 5
            },
            (
              _,
              index
            ) => ({
              activityId:
                "warna-merah-001",

              completedAt:
                new Date(
                  now.getTime() -
                  index *
                    60 *
                    60 *
                    1000
                ).toISOString(),

              correctCount:
                4,

              incorrectCount:
                1,

              attempts:
                5,

              durationSeconds:
                60
            })
          );


        const result =
          analyseLearningSessions(
            sessions,
            now
          );


        expect(
          result.objectives[0]
            ?.signal
        ).toBe(
          "showing-confidence"
        );
      }
    );


    it(
      "counts recent exposure separately",
      () => {
        const result =
          analyseLearningSessions(
            [
              {
                activityId:
                  "warna-merah-001",

                completedAt:
                  "2026-08-19T10:00:00.000Z",

                correctCount:
                  1,

                incorrectCount:
                  0,

                attempts:
                  1,

                durationSeconds:
                  60
              },

              {
                activityId:
                  "warna-merah-001",

                completedAt:
                  "2026-06-01T10:00:00.000Z",

                correctCount:
                  1,

                incorrectCount:
                  0,

                attempts:
                  1,

                durationSeconds:
                  60
              }
            ],
            now
          );


        expect(
          result.objectives[0]
            ?.exposureCount
        ).toBe(2);

        expect(
          result.objectives[0]
            ?.recentExposureCount
        ).toBe(1);
      }
    );


    it(
      "calculates total learning time without creating a reward metric",
      () => {
        const result =
          analyseLearningSessions(
            [
              {
                activityId:
                  "warna-merah-001",

                completedAt:
                  "2026-08-20T10:00:00.000Z",

                correctCount:
                  1,

                incorrectCount:
                  0,

                attempts:
                  1,

                durationSeconds:
                  90
              },

              {
                activityId:
                  "warna-merah-001",

                completedAt:
                  "2026-08-20T11:00:00.000Z",

                correctCount:
                  1,

                incorrectCount:
                  0,

                attempts:
                  1,

                durationSeconds:
                  90
              }
            ],
            now
          );


        expect(
          result.totalLearningMinutes
        ).toBe(3);
      }
    );
  }
);
