import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const rawArgs =
  process.argv.slice(2);

const activityId =
  rawArgs[0];

const optionArgs =
  rawArgs.slice(1);

const options = {};

for (
  let index = 0;
  index < optionArgs.length;
  index += 1
) {
  const token =
    optionArgs[index];

  if (
    !token.startsWith("--")
  ) {
    console.error(
      `Unexpected argument: ${token}`
    );

    process.exit(1);
  }

  const key =
    token.slice(2);

  const value =
    optionArgs[index + 1];

  if (
    !value ||
    value.startsWith("--")
  ) {
    console.error(
      `Missing value for --${key}`
    );

    process.exit(1);
  }

  if (
    Object.prototype.hasOwnProperty.call(
      options,
      key
    )
  ) {
    console.error(
      `Duplicate option: --${key}`
    );

    process.exit(1);
  }

  options[key] =
    value;

  index += 1;
}

const allowedOptions =
  new Set([
    "age-band",
    "difficulty",
    "primary-skill",
    "sequence"
  ]);

for (
  const key of
    Object.keys(options)
) {
  if (
    !allowedOptions.has(
      key
    )
  ) {
    console.error(
      `Unknown option: --${key}`
    );

    process.exit(1);
  }
}

const ageBand =
  options["age-band"] ??
    "3-4";

if (
  ![
    "2-3",
    "3-4",
    "4-5",
    "5-6"
  ].includes(
    ageBand
  )
) {
  console.error(
    `Invalid age band: ${ageBand}`
  );

  process.exit(1);
}

const difficulty =
  options.difficulty ===
    undefined
    ? 1
    : Number(
        options.difficulty
      );

if (
  !Number.isInteger(
    difficulty
  ) ||
  difficulty < 1 ||
  difficulty > 5
) {
  console.error(
    "Difficulty must be an integer from 1 to 5."
  );

  process.exit(1);
}

const primarySkill =
  options["primary-skill"] ??
    "visual-discrimination";

if (
  !/^[a-z0-9-]+$/.test(
    primarySkill
  )
) {
  console.error(
    `Invalid primary skill ID: ${primarySkill}`
  );

  process.exit(1);
}

const explicitSequence =
  options.sequence ===
    undefined
    ? null
    : Number(
        options.sequence
      );

if (
  explicitSequence !== null &&
  (
    !Number.isInteger(
      explicitSequence
    ) ||
    explicitSequence < 1
  )
) {
  console.error(
    "Sequence must be a positive integer."
  );

  process.exit(1);
}


if (
  !activityId ||
  !/^[a-z0-9-]+$/.test(
    activityId
  )
) {
  console.error(
    "Usage: node tools/content-compiler/new-activity.mjs <activity-id> [--age-band 2-3|3-4|4-5|5-6] [--difficulty 1-5] [--primary-skill <skill-id>] [--sequence <positive-integer>]"
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


const manifestDirectory =
  path.dirname(
    target
  );

const existingSequences =
  fs.existsSync(
    manifestDirectory
  )
    ? fs.readdirSync(
        manifestDirectory
      )
        .filter(
          file =>
            file.endsWith(
              ".json"
            )
        )
        .map(
          file => {
            try {
              const existing =
                JSON.parse(
                  fs.readFileSync(
                    path.join(
                      manifestDirectory,
                      file
                    ),
                    "utf8"
                  )
                );

              return Number.isInteger(
                existing.catalogue?.sequence
              )
                ? existing.catalogue.sequence
                : 0;
            }
            catch {
              return 0;
            }
          }
        )
    : [];

const nextSequence =
  (
    existingSequences.length
      ? Math.max(
          ...existingSequences
        )
      : 0
  ) +
  10;


const manifest = {
  exportName,

  activity: {
    id:
      activityId,

    version:
      1,

    mechanic:
      "tap-choice",

    ageBand,

    domains: [
      "logic"
    ],

    skills: [
      primarySkill
    ],

    difficulty,

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

    sequence:
      explicitSequence ??
        nextSequence,

    ageBands: [
      ageBand
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
  },

  curriculumMappings:
    [],

  skillMappings: [
    {
      skillId:
        primarySkill,

      role:
        "primary",

      weight:
        1
    }
  ]
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
