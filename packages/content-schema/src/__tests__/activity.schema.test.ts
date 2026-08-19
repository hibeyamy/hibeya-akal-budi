import {
  describe,
  expect,
  it
} from "vitest";

import {
  ActivitySchema
} from "../activity.schema";

describe("ActivitySchema", () => {
  it("accepts a valid activity", () => {
    const result = ActivitySchema.safeParse({
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
    });

    expect(result.success).toBe(true);
  });

  it("rejects an invalid age band", () => {
    const result = ActivitySchema.safeParse({
      id: "invalid-001",
      version: 1,
      mechanic: "tap-choice",
      ageBand: "99-100",
      domains: ["logic"],
      skills: ["colour-recognition"],
      difficulty: 1,

      title: {
        ms: "Ujian",
        en: "Test"
      },

      instruction: {
        ms: "Pilih",
        en: "Choose"
      },

      options: [
        {
          id: "a",
          asset: "a",
          correct: true
        },
        {
          id: "b",
          asset: "b",
          correct: false
        }
      ],

      metadata: {
        estimatedSeconds: 30,
        active: true
      }
    });

    expect(result.success).toBe(false);
  });

  it("rejects difficulty above five", () => {
    const result = ActivitySchema.safeParse({
      id: "invalid-002",
      version: 1,
      mechanic: "tap-choice",
      ageBand: "3-4",
      domains: ["logic"],
      skills: ["colour-recognition"],
      difficulty: 10,

      title: {
        ms: "Ujian",
        en: "Test"
      },

      instruction: {
        ms: "Pilih",
        en: "Choose"
      },

      options: [
        {
          id: "a",
          asset: "a",
          correct: true
        },
        {
          id: "b",
          asset: "b",
          correct: false
        }
      ],

      metadata: {
        estimatedSeconds: 30,
        active: true
      }
    });

    expect(result.success).toBe(false);
  });
});
