import {
  ActivitySchema,
  type ActivityContent
} from "@akal-budi/content-schema";

const activity = {
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
    },
    {
      id: "banana-yellow",
      asset: "banana-yellow",
      correct: false
    }
  ],

  metadata: {
    estimatedSeconds: 30,
    active: true
  }
} satisfies ActivityContent;

export const warnaMerah001 = ActivitySchema.parse(activity);
