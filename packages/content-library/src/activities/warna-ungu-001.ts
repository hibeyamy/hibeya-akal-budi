import {
  ActivitySchema,
  type ActivityContent
} from "@akal-budi/content-schema";


const activity:
  ActivityContent =
{
  "id": "warna-ungu-001",
  "version": 1,
  "mechanic": "tap-choice",
  "ageBand": "3-4",
  "domains": [
    "logic"
  ],
  "skills": [
    "colour-recognition",
    "visual-discrimination"
  ],
  "difficulty": 2,
  "title": {
    "ms": "Cari Warna Ungu",
    "en": "Find Purple"
  },
  "instruction": {
    "ms": "Cari bunga raya yang berwarna ungu",
    "en": "Find the hibiscus that is purple"
  },
  "options": [
    {
      "id": "hibiscus-red",
      "asset": "hibiscus-red",
      "correct": false
    },
    {
      "id": "hibiscus-purple",
      "asset": "hibiscus-purple",
      "correct": true
    },
    {
      "id": "hibiscus-yellow",
      "asset": "hibiscus-yellow",
      "correct": false
    }
  ],
  "development": {
    "objectiveIds": [
      "visual-colour-recognition",
      "local-environment-awareness"
    ],
    "rationale": {
      "ms": "Aktiviti tahap dua memperluas pengecaman warna kepada warna ungu sambil mengekalkan bentuk bunga yang sama.",
      "en": "This level-two activity extends colour recognition to purple while keeping the flower shape consistent."
    },
    "interactionMode": "independent",
    "estimatedMinutes": 2,
    "parentParticipationRecommended": false,
    "offlineExtension": {
      "ms": "Jika ada tumbuhan berbunga berdekatan, lihat bersama orang dewasa dan berbual tentang warna bunganya.",
      "en": "If there are flowering plants nearby, look at them with an adult and talk about their colours."
    },
    "researchRefs": [
      "AB-RESEARCH-EARLY-PLAY-001"
    ]
  },
  "wellbeing": {
    "sensoryLoad": "low",
    "rewardIntensity": 1,
    "animationIntensity": 0,
    "audioIntensity": 0,
    "usesCountdownPressure": false,
    "usesLossAversion": false,
    "usesStreakPressure": false,
    "usesInfinitePlay": false,
    "usesBehaviouralAds": false,
    "penalisesMistakes": false
  },
  "malaysia": {
    "relevance": "core",
    "elements": [
      "bunga raya"
    ],
    "culturalReviewRequired": false
  },
  "accessibility": {
    "reducedMotionSafe": true,
    "requiresReading": false,
    "requiresAudio": false,
    "colourIsLearningTarget": false,
    "largeTouchTargets": true,
    "alternativeInstructionAvailable": true
  },
  "provenance": {
    "type": "original",
    "creator": "HIBEYA",
    "assetSourceRefs": [
      "hibiscus-red",
      "hibiscus-purple",
      "hibiscus-yellow"
    ],
    "originalityReviewed": true,
    "culturalReviewed": true,
    "reviewedBy": "HIBEYA OpenAI-assisted content review",
    "reviewedAt": "2026-08-26T09:58:13.463Z"
  },
  "metadata": {
    "estimatedSeconds": 90,
    "active": true
  }
};


export const warnaUngu001 =
  ActivitySchema.parse(
    activity
  );
