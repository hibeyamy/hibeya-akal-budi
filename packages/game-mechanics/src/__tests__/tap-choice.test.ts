import {
  describe,
  expect,
  it
} from "vitest";

import {
  governedActivityFixture
} from "@akal-budi/test-fixtures";

import {
  TapChoiceMechanic
} from "../tap-choice";

describe("TapChoiceMechanic", () => {
  it("accepts a governed tap-choice activity", () => {
    const mechanic =
      new TapChoiceMechanic();

    const context =
      mechanic.start(
        governedActivityFixture
      );

    expect(
      context.activity.id
    ).toBe(
      governedActivityFixture.id
    );
  });

  it("returns correct for the correct option", () => {
    const mechanic =
      new TapChoiceMechanic();

    const context =
      mechanic.start(
        governedActivityFixture
      );

    const answer =
      mechanic.submitAnswer(
        context,
        "apple-red"
      );

    expect(answer.correct)
      .toBe(true);
  });

  it("returns incorrect for the wrong option", () => {
    const mechanic =
      new TapChoiceMechanic();

    const context =
      mechanic.start(
        governedActivityFixture
      );

    const answer =
      mechanic.submitAnswer(
        context,
        "apple-green"
      );

    expect(answer.correct)
      .toBe(false);
  });

  it("rejects an unknown option", () => {
    const mechanic =
      new TapChoiceMechanic();

    const context =
      mechanic.start(
        governedActivityFixture
      );

    expect(() =>
      mechanic.submitAnswer(
        context,
        "does-not-exist"
      )
    ).toThrow(
      "Unknown option"
    );
  });

  it("rejects an activity intended for another mechanic", () => {
    const mechanic =
      new TapChoiceMechanic();

    expect(() =>
      mechanic.start({
        ...governedActivityFixture,
        mechanic: "memory"
      })
    ).toThrow(
      "TapChoiceMechanic cannot run activity mechanic"
    );
  });
});
