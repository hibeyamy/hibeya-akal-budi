import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const [
  ,
  ,
  activityId
] =
  process.argv;


if (
  !activityId ||
  !/^[a-z0-9-]+$/.test(
    activityId
  )
) {
  console.error(
    "Usage: node tools/content-compiler/new-activity.mjs <activity-id>"
  );

  process.exit(1);
}


const repoRoot =
  process.cwd();

const target =
  path.join(
    repoRoot,
    "content",
    "activity-manifests",
    `${activityId}.json`
  );


if (
  fs.existsSync(
    target
  )
) {
  console.error(
    `Manifest already exists: ${target}`
  );

  process.exit(1);
}


const exportName =
  activityId
    .split("-")
    .map(
      (
        part,
        index
      ) =>
        index ===
          0
          ? part
          : part
              .charAt(0)
              .toUpperCase() +
            part.slice(1)
    )
    .join("")
    .replace(
      /[^a-zA-Z0-9_$]/g,
      ""
    );


const manifest = {
  exportName,

  activity: {
    id:
      activityId,

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
      "visual-discrimination"
    ],

    difficulty:
      1,

    title: {
      ms:
        "TODO",

      en:
        "TODO"
    },

    instruction: {
      ms:
        "TODO",

      en:
        "TODO"
    },

    options: [
      {
        id:
          "TODO-correct",

        asset:
          "TODO",

        correct:
          true
      },

      {
        id:
          "TODO-other",

        asset:
          "TODO",

        correct:
          false
      }
    ],

    development: {
      objectiveIds: [
        "TODO"
      ],

      rationale: {
        ms:
          "TODO",

        en:
          "TODO"
      },

      interactionMode:
        "independent",

      estimatedMinutes:
        2,

      parentParticipationRecommended:
        false,

      offlineExtension: {
        ms:
          "TODO",

        en:
          "TODO"
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
        "supporting",

      elements: [],

      culturalReviewRequired:
        true
    },

    accessibility: {
      reducedMotionSafe:
        true,

      requiresReading:
        false,

      requiresAudio:
        false,

      colourIsLearningTarget:
        false,

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
        false,

      culturalReviewed:
        false,

      reviewedBy:
        "PENDING",

      reviewedAt:
        new Date(
          0
        ).toISOString()
    },

    metadata: {
      estimatedSeconds:
        120,

      active:
        false
    }
  },

  catalogue: {
    blueprintId:
      "TODO",

    enabled:
      false,

    ageBands: [
      "3-4"
    ],

    titleMs:
      "TODO",

    titleEn:
      "TODO",

    implementationKey:
      "colour-choice-v1"
  },

  learningInsights: {
    objectives: [],
    malaysiaElements: []
  }
};


fs.mkdirSync(
  path.dirname(
    target
  ),
  {
    recursive:
      true
  }
);


fs.writeFileSync(
  target,
  JSON.stringify(
    manifest,
    null,
    2
  ) +
  "\n",
  "utf8"
);


console.log(
  `CREATED: ${path.relative(repoRoot, target)}`
);

console.log(
  "Complete the TODO fields, provenance review and cultural review before enabling the activity."
);
