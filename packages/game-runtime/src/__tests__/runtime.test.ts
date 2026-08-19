import {
  describe,
  expect,
  it,
  vi
} from "vitest";

import type {
  ActivityContent
} from "@akal-budi/content-schema";

import {
  createSessionContext,
  createSessionResult
} from "../runtime";

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

describe("game runtime", () => {
  it("creates a session context", () => {
    vi.spyOn(Date, "now")
      .mockReturnValue(1000);

    const context =
      createSessionContext(activity);

    expect(context.activity.id)
      .toBe("warna-merah-001");

    expect(context.startedAt)
      .toBe(1000);

    vi.restoreAllMocks();
  });

  it("creates a correct session result", () => {
    vi.spyOn(Date, "now")
      .mockReturnValue(6000);

    const context = {
      activity,
      startedAt: 1000
    };

    const result =
      createSessionResult(
        context,
        [
          {
            optionId: "apple-green",
            correct: false,
            answeredAt: 2000
          },
          {
            optionId: "apple-red",
            correct: true,
            answeredAt: 3000
          }
        ]
      );

    expect(result.correct).toBe(1);
    expect(result.incorrect).toBe(1);
    expect(result.attempts).toBe(2);
    expect(result.durationSeconds).toBe(5);
    expect(result.activityVersion).toBe(1);

    vi.restoreAllMocks();
  });
});
