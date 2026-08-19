import type {
  ActivityContent
} from "@akal-budi/content-schema";

export const governedActivityFixture: ActivityContent = {
  id: "warna-merah-test-001",

  version: 1,

  mechanic: "tap-choice",

  ageBand: "3-4",

  domains: [
    "logic"
  ],

  skills: [
    "colour-recognition",
    "visual-discrimination"
  ],

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

  development: {
    objectiveIds: [
      "visual-colour-recognition"
    ],

    rationale: {
      ms:
        "Aktiviti ujian untuk mengesahkan pengenalan warna dan diskriminasi visual.",
      en:
        "Test activity for validating colour recognition and visual discrimination."
    },

    interactionMode:
      "independent",

    estimatedMinutes: 2,

    parentParticipationRecommended:
      false,

    offlineExtension: {
      ms:
        "Cari satu benda merah di sekeliling.",
      en:
        "Find one red object around you."
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
      "HIBEYA Test Fixture",

    assetSourceRefs: [],

    originalityReviewed:
      true,

    culturalReviewed:
      true,

    reviewedBy:
      "Automated test fixture",

    reviewedAt:
      "2026-08-20T00:00:00.000Z"
  },

  metadata: {
    estimatedSeconds:
      120,

    active:
      true
  }
};
