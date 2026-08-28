import {
  ActivitySchema,
  type ActivityContent
} from "@akal-budi/content-schema";


const activity:
  ActivityContent =
{
  "id": "beza-buah-001",
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
    "ms": "Buah Mana Berbeza?",
    "en": "Which Fruit Is Different?"
  },
  "instruction": {
    "ms": "Cari buah yang berbeza daripada dua yang sama",
    "en": "Find the fruit that is different from the two matching fruits"
  },
  "options": [
    {
      "id": "apple-red-a",
      "asset": "apple-red",
      "correct": false
    },
    {
      "id": "apple-red-b",
      "asset": "apple-red",
      "correct": false
    },
    {
      "id": "banana-yellow",
      "asset": "banana-yellow",
      "correct": true
    }
  ],
  "development": {
    "objectiveIds": [
      "visual-discrimination"
    ],
    "rationale": {
      "ms": "Aktiviti ini melatih diskriminasi visual melalui dua buah yang sama dan satu buah yang berbeza.",
      "en": "This activity develops visual discrimination using two matching fruits and one different fruit."
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
    "relevance": "neutral",
    "elements": [],
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
      "apple-red",
      "banana-yellow"
    ],
    "originalityReviewed": true,
    "culturalReviewed": true,
    "reviewedBy": "HIBEYA OpenAI-assisted content review",
    "reviewedAt": "2026-08-26T09:58:13.463Z"
  },
  "metadata": {
    "estimatedSeconds": 120,
    "active": true
  }
};


export const bezaBuah001 =
  ActivitySchema.parse(
    activity
  );
