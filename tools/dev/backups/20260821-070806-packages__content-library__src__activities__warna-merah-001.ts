import {
  ActivitySchema,
  type ActivityContent
} from "@akal-budi/content-schema";


const activity =
{
  "id": "warna-merah-001",
  "version": 2,
  "mechanic": "tap-choice",
  "ageBand": "3-4",
  "domains": [
    "logic"
  ],
  "skills": [
    "colour-recognition",
    "visual-discrimination"
  ],
  "difficulty": 1,
  "title": {
    "ms": "Cari Warna Merah",
    "en": "Find the Red Colour"
  },
  "instruction": {
    "ms": "Cari buah yang berwarna merah",
    "en": "Find the fruit that is red"
  },
  "options": [
    {
      "id": "apple-red",
      "asset": "apple-red",
      "correct": true
    },
    {
      "id": "apple-green",
      "asset": "apple-green",
      "correct": false
    },
    {
      "id": "banana-yellow",
      "asset": "banana-yellow",
      "correct": false
    }
  ],
  "development": {
    "objectiveIds": [
      "visual-colour-recognition"
    ],
    "rationale": {
      "ms": "Aktiviti ini membantu kanak-kanak membezakan dan mengenal warna melalui pilihan visual yang mudah.",
      "en": "This activity supports basic colour recognition and visual discrimination through simple visual choices."
    },
    "interactionMode": "independent",
    "estimatedMinutes": 2,
    "parentParticipationRecommended": false,
    "offlineExtension": {
      "ms": "Cari tiga benda berwarna merah di sekeliling bersama orang dewasa.",
      "en": "Find three red objects around you with an adult."
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
    "colourIsLearningTarget": true,
    "largeTouchTargets": true,
    "alternativeInstructionAvailable": true
  },
  "provenance": {
    "type": "original",
    "creator": "HIBEYA",
    "assetSourceRefs": [],
    "originalityReviewed": true,
    "culturalReviewed": true,
    "reviewedBy": "HIBEYA internal review",
    "reviewedAt": "2026-08-20T00:00:00.000Z"
  },
  "metadata": {
    "estimatedSeconds": 120,
    "active": true
  }
}
  satisfies ActivityContent;


export const warnaMerah001 =
  ActivitySchema.parse(
    activity
  );
