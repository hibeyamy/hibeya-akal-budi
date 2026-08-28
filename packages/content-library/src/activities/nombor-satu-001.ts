import {
  ActivitySchema,
  type ActivityContent
} from "@akal-budi/content-schema";


const activity:
  ActivityContent =
{
  "id": "nombor-satu-001",
  "version": 1,
  "mechanic": "tap-choice",
  "ageBand": "3-4",
  "domains": [
    "logic"
  ],
  "skills": [
    "early-numeracy"
  ],
  "difficulty": 1,
  "title": {
    "ms": "Cari satu",
    "en": "Find one"
  },
  "instruction": {
    "ms": "Pilih kumpulan yang ada satu epal.",
    "en": "Choose the group with one apple."
  },
  "options": [
    {
      "id": "option-1",
      "asset": "quantity-apple-1",
      "correct": true
    },
    {
      "id": "option-2",
      "asset": "quantity-apple-2",
      "correct": false
    },
    {
      "id": "option-3",
      "asset": "quantity-apple-3",
      "correct": false
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


export const nomborSatu001 =
  ActivitySchema.parse(
    activity
  );
