import {
  describe,
  expect,
  it
} from "vitest";

import type {
  ActivityContent
} from "@akal-budi/content-schema";

import {
  TapChoiceMechanic
} from "../tap-choice";

const activity: ActivityContent = {
  id: "warna-merah-001",
  version: 1,
  mechanic: "tap-choice",
  ageBand: "3-4",
  domains: ["logic"],
  skills: ["colour-recognition"],
  difficulty: 1,

  title: {
    ms: "Cari Warna Merah",
    en: "Find the Red Colour"
  },

  instruction: {
    ms: "Cari buah yang berwarna merah",
    en: "Find the fruit that is red"
  },

  options: [
    {
      id: "apple-red",
      asset: "apple-red",
      correct: true
    },
    {
      id: "apple-green",
      asset: "apple-green",
      correct: false
    }
  ],

  metadata: {
    estimatedSeconds: 30,
    active: true
  }
};

describe("TapChoiceMechanic", () => {
  it("returns correct result for the correct option", () => {
    const mechanic =
      new TapChoiceMechanic();

    const context =
      mechanic.start(activity);

    const answer =
      mechanic.submitAnswer(
        context,
        "apple-red"
      );

    expect(answer.correct)
      .toBe(true);
  });

  it("returns incorrect result for a wrong option", () => {
    const mechanic =
      new TapChoiceMechanic();

    const context =
      mechanic.start(activity);

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
      mechanic.start(activity);

    expect(() =>
      mechanic.submitAnswer(
        context,
        "does-not-exist"
      )
    ).toThrow("Unknown option");
  });

  it("rejects the wrong mechanic type", () => {
    const mechanic =
      new TapChoiceMechanic();

    expect(() =>
      mechanic.start({
        ...activity,
        mechanic: "memory"
      })
    ).toThrow();
  });
});
