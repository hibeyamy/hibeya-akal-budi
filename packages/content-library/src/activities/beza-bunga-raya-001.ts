import {
  ActivitySchema,
  type ActivityContent
} from "@akal-budi/content-schema";


const activity:
  ActivityContent =
{
  "id": "beza-bunga-raya-001",
  "version": 1,
  "mechanic": "tap-choice",
  "ageBand": "3-4",
  "domains": [
    "logic"
  ],
  "skills": [
    "visual-discrimination",
    "colour-recognition"
  ],
  "difficulty": 1,
  "title": {
    "ms": "Yang Mana Berbeza?",
    "en": "Which One Is Different?"
  },
  "instruction": {
    "ms": "Cari bunga raya yang berbeza",
    "en": "Find the hibiscus that is different"
  },
  "options": [
    {
      "id": "hibiscus-red-left",
      "asset": "hibiscus-red",
      "correct": false
    },
    {
      "id": "hibiscus-red-right",
      "asset": "hibiscus-red",
      "correct": false
    },
    {
      "id": "hibiscus-yellow-different",
      "asset": "hibiscus-yellow",
      "correct": true
    }
  ],
  "development": {
    "objectiveIds": [
      "visual-discrimination"
    ],
    "rationale": {
      "ms": "Aktiviti ini memberi latihan diskriminasi visual asas dengan meminta kanak-kanak mengenal satu imej yang berbeza daripada dua imej yang sama.",
      "en": "This activity practises basic visual discrimination by asking the learner to identify one image that differs from two matching images."
    },
    "interactionMode": "independent",
    "estimatedMinutes": 2,
    "parentParticipationRecommended": false,
    "offlineExtension": {
      "ms": "Susun tiga objek selamat bersama orang dewasa, dengan dua objek yang sama dan satu yang berbeza. Cari objek yang berbeza.",
      "en": "With an adult, arrange three safe objects with two alike and one different. Find the object that is different."
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
    "culturalReviewRequired": true
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
    "assetSourceRefs": [],
    "originalityReviewed": true,
    "culturalReviewed": true,
    "reviewedBy": "HilmiBeya",
    "reviewedAt": "2026-08-26T05:03:11.772Z"
  },
  "metadata": {
    "estimatedSeconds": 120,
    "active": true
  }
};


export const bezaBungaRaya001 =
  ActivitySchema.parse(
    activity
  );
