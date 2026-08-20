import {
  ActivitySchema,
  type ActivityContent
} from "@akal-budi/content-schema";


const activity = {
  id:
    "warna-bunga-raya-001",

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
    "colour-recognition",
    "visual-discrimination"
  ],

  difficulty:
    1,


  title: {
    ms:
      "Mana Bunga Raya Merah?",

    en:
      "Which Hibiscus Is Red?"
  },


  instruction: {
    ms:
      "Cari bunga raya yang berwarna merah",

    en:
      "Find the hibiscus that is red"
  },


  options: [
    {
      id:
        "hibiscus-red",

      asset:
        "hibiscus-red",

      correct:
        true
    },

    {
      id:
        "hibiscus-yellow",

      asset:
        "hibiscus-yellow",

      correct:
        false
    },

    {
      id:
        "hibiscus-purple",

      asset:
        "hibiscus-purple",

      correct:
        false
    }
  ],


  development: {
    objectiveIds: [
      "visual-colour-recognition",
      "local-environment-awareness"
    ],


    rationale: {
      ms:
        "Aktiviti ini memberi peluang kepada kanak-kanak mengenal warna merah melalui bunga raya sebagai unsur tempatan yang dekat dengan identiti Malaysia.",

      en:
        "This activity gives children an opportunity to recognise red using the hibiscus as a locally relevant Malaysian element."
    },


    interactionMode:
      "independent",


    estimatedMinutes:
      2,


    parentParticipationRecommended:
      false,


    offlineExtension: {
      ms:
        "Jika ada tumbuhan berbunga berdekatan, lihat bersama orang dewasa dan berbual tentang warna bunganya.",

      en:
        "If there are flowering plants nearby, look at them with an adult and talk about their colours."
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
      "core",

    elements: [
      "bunga raya"
    ],

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
      "HIBEYA internal review",

    reviewedAt:
      "2026-08-20T00:00:00.000Z"
  },


  metadata: {
    estimatedSeconds:
      90,

    active:
      true
  }

} satisfies ActivityContent;


export const warnaBungaRaya001 =
  ActivitySchema.parse(
    activity
  );
  