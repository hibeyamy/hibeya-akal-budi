import {
  afterEach,
  describe,
  expect,
  it,
  vi
} from "vitest";

import {
  governedActivityFixture
} from "@akal-budi/test-fixtures";

import {
  createSessionContext,
  createSessionResult
} from "../runtime";

describe("game runtime", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("creates a session context", () => {
    vi.spyOn(Date, "now")
      .mockReturnValue(1000);

    const context =
      createSessionContext(
        governedActivityFixture
      );

    expect(
      context.activity.id
    ).toBe(
      "warna-merah-test-001"
    );

    expect(
      context.startedAt
    ).toBe(1000);
  });

  it("creates a correct session result", () => {
    vi.spyOn(Date, "now")
      .mockReturnValue(6000);

    const context = {
      activity:
        governedActivityFixture,

      startedAt:
        1000
    };

    const result =
      createSessionResult(
        context,
        [
          {
            optionId:
              "apple-green",

            correct:
              false,

            answeredAt:
              2000
          },
          {
            optionId:
              "apple-red",

            correct:
              true,

            answeredAt:
              3000
          }
        ]
      );

    expect(result.correct)
      .toBe(1);

    expect(result.incorrect)
      .toBe(1);

    expect(result.attempts)
      .toBe(2);

    expect(result.durationSeconds)
      .toBe(5);

    expect(result.activityVersion)
      .toBe(1);

    expect(result.activityId)
      .toBe(
        "warna-merah-test-001"
      );
  });
});
