import type {
  ActivityBlueprint
} from "./types";


export const activityBlueprints:
  readonly ActivityBlueprint[] = [

    {
      id:
        "warna-bunga-raya",

      titleMs:
        "Mana Bunga Raya Merah?",

      titleEn:
        "Which Hibiscus Is Red?",

      ageBands: [
        "2-3",
        "3-4"
      ],

      domains: [
        "visual-perception",
        "language"
      ],

      mechanic:
        "tap-choice",

      themeId:
        "taman-malaysia",

      learningObjectiveIds: [
        "colour-recognition",
        "malay-vocabulary",
        "malaysian-context"
      ],

      difficulty:
        1,

      intensity:
        "very-light",

      targetDurationSeconds: {
        min: 20,
        max: 60
      },

      malaysiaElements: [
        "bunga raya"
      ],

      originalityNote:
        "Original Akal Budi scene and interaction using a locally familiar flower rather than copying an existing worksheet or app composition.",

      healthyUseNote:
        "One short choice sequence with no timer, score pressure or forced replay."
    },


    {
      id:
        "bakul-pasar",

      titleMs:
        "Masuk Dalam Bakul",

      titleEn:
        "Into the Basket",

      ageBands: [
        "3-4",
        "4-5"
      ],

      domains: [
        "thinking",
        "early-numeracy",
        "world-around-us"
      ],

      mechanic:
        "sorting",

      themeId:
        "pasar-pagi",

      learningObjectiveIds: [
        "visual-matching",
        "early-counting",
        "malaysian-context"
      ],

      difficulty:
        2,

      intensity:
        "light",

      targetDurationSeconds: {
        min: 40,
        max: 100
      },

      malaysiaElements: [
        "rambutan",
        "pisang",
        "bakul pasar"
      ],

      originalityNote:
        "Original sorting task based on a Malaysian morning-market setting.",

      healthyUseNote:
        "No countdown. Child may retry calmly and stop after one completed round."
    },


    {
      id:
        "jejak-tapir",

      titleMs:
        "Cari Laluan Tapir",

      titleEn:
        "Find the Tapir's Path",

      ageBands: [
        "4-5",
        "5-6"
      ],

      domains: [
        "thinking",
        "world-around-us"
      ],

      mechanic:
        "sequence",

      themeId:
        "hutan-hujan",

      learningObjectiveIds: [
        "environment-awareness",
        "malaysian-context"
      ],

      difficulty:
        3,

      intensity:
        "light",

      targetDurationSeconds: {
        min: 60,
        max: 150
      },

      malaysiaElements: [
        "tapir Malaya",
        "hutan hujan",
        "sungai"
      ],

      originalityNote:
        "Original route-sequencing mechanic using a Malaysian rainforest narrative.",

      healthyUseNote:
        "No lives system. Incorrect route choices produce neutral guidance rather than punishment."
    },


    {
      id:
        "susun-perjalanan-lrt",

      titleMs:
        "Apa Yang Berlaku Dulu?",

      titleEn:
        "What Happens First?",

      ageBands: [
        "5-6"
      ],

      domains: [
        "thinking",
        "language",
        "world-around-us"
      ],

      mechanic:
        "sequence",

      themeId:
        "perjalanan-harian",

      learningObjectiveIds: [
        "visual-matching",
        "malay-vocabulary",
        "malaysian-context"
      ],

      difficulty:
        4,

      intensity:
        "moderate",

      targetDurationSeconds: {
        min: 70,
        max: 180
      },

      malaysiaElements: [
        "LRT",
        "platform",
        "kad perjalanan"
      ],

      originalityNote:
        "Original everyday-sequencing activity based on Malaysian urban transport.",

      healthyUseNote:
        "Finite three-step sequences with no competitive scoring."
    }

  ];
  