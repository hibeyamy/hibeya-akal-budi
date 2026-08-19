import {
  describe,
  expect,
  it
} from "vitest";

import {
  ActivitySchema
} from "../activity.schema";

const validActivity = {
  id:
    "governance-test-001",

  version:
    1,

  mechanic:
    "tap-choice",

  ageBand:
    "3-4",

  domains: [
    "logic"
  ],

  skills: [
    "colour-recognition"
  ],

  difficulty:
    1,

  title: {
    ms:
      "Cari Warna Merah",

    en:
      "Find the Red Colour"
  },

  instruction: {
    ms:
      "Cari buah yang berwarna merah",

    en:
      "Find the fruit that is red"
  },

  options: [
    {
      id:
        "apple-red",

      asset:
        "apple-red",

      correct:
        true
    },
    {
      id:
        "apple-green",

      asset:
        "apple-green",

      correct:
        false
    }
  ],

  development: {
    objectiveIds: [
      "visual-colour-recognition"
    ],

    rationale: {
      ms:
        "Menyokong pengenalan warna.",

      en:
        "Supports colour recognition."
    },

    interactionMode:
      "independent",

    estimatedMinutes:
      2,

    parentParticipationRecommended:
      false,

    offlineExtension: {
      ms:
        "Cari benda merah.",

      en:
        "Find a red object."
    },

    researchRefs: [
      "AB-RESEARCH-EARLY-PLAY-001"
    ]
  },

  wellbeing: {
    sensoryLoad:
      "low",

    rewardIntensity:
      1,

    animationIntensity:
      0,

    audioIntensity:
      0,

    usesCountdownPressure:
      false,

    usesLossAversion:
      false,

    usesStreakPressure:
      false,

    usesInfinitePlay:
      false,

    usesBehaviouralAds:
      false,

    penalisesMistakes:
      false
  },

  malaysia: {
    relevance:
      "neutral",

    elements: [],

    culturalReviewRequired:
      false
  },

  accessibility: {
    reducedMotionSafe:
      true,

    requiresReading:
      false,

    requiresAudio:
      false,

    colourIsLearningTarget:
      true,

    largeTouchTargets:
      true,

    alternativeInstructionAvailable:
      true
  },

  provenance: {
    type:
      "original",

    creator:
      "HIBEYA",

    assetSourceRefs: [],

    originalityReviewed:
      true,

    culturalReviewed:
      true,

    reviewedBy:
      "Test review",

    reviewedAt:
      "2026-08-20T00:00:00.000Z"
  },

  metadata: {
    estimatedSeconds:
      120,

    active:
      true
  }
} as const;

describe("ActivitySchema governance", () => {
  it("accepts a fully governed activity", () => {
    const result =
      ActivitySchema.safeParse(
        validActivity
      );

    expect(result.success)
      .toBe(true);
  });

  it("rejects an invalid age band", () => {
    const result =
      ActivitySchema.safeParse({
        ...validActivity,
        ageBand:
          "99-100"
      });

    expect(result.success)
      .toBe(false);
  });

  it("rejects difficulty above five", () => {
    const result =
      ActivitySchema.safeParse({
        ...validActivity,
        difficulty:
          10
      });

    expect(result.success)
      .toBe(false);
  });

  it("rejects countdown pressure", () => {
    const result =
      ActivitySchema.safeParse({
        ...validActivity,

        wellbeing: {
          ...validActivity.wellbeing,

          usesCountdownPressure:
            true
        }
      });

    expect(result.success)
      .toBe(false);
  });

  it("rejects behavioural advertising", () => {
    const result =
      ActivitySchema.safeParse({
        ...validActivity,

        wellbeing: {
          ...validActivity.wellbeing,

          usesBehaviouralAds:
            true
        }
      });

    expect(result.success)
      .toBe(false);
  });

  it("rejects Malaysian relevance without identified elements", () => {
    const result =
      ActivitySchema.safeParse({
        ...validActivity,

        malaysia: {
          relevance:
            "core",

          elements:
            [],

          culturalReviewRequired:
            true
        }
      });

    expect(result.success)
      .toBe(false);
  });

  it("requires a licence reference for licensed content", () => {
    const result =
      ActivitySchema.safeParse({
        ...validActivity,

        provenance: {
          ...validActivity.provenance,

          type:
            "licensed"
        }
      });

    expect(result.success)
      .toBe(false);
  });

  it("rejects activities longer than the initial healthy-play limit", () => {
    const result =
      ActivitySchema.safeParse({
        ...validActivity,

        development: {
          ...validActivity.development,

          estimatedMinutes:
            30
        }
      });

    expect(result.success)
      .toBe(false);
  });
});
