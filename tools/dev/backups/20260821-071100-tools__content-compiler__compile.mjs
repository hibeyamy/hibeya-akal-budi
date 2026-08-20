import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const repoRoot =
  process.cwd();

const manifestRoot =
  path.join(
    repoRoot,
    "content",
    "activity-manifests"
  );


function fail(message) {
  console.error(
    `CONTENT COMPILER ERROR: ${message}`
  );

  process.exit(1);
}


function readJson(filePath) {
  try {
    return JSON.parse(
      fs.readFileSync(
        filePath,
        "utf8"
      )
    );
  } catch (error) {
    fail(
      `Cannot parse ${filePath}: ${error.message}`
    );
  }
}


function assert(
  condition,
  message
) {
  if (!condition) {
    fail(message);
  }
}


function assertString(
  value,
  label
) {
  assert(
    typeof value ===
      "string" &&
    value.length >
      0,
    `${label} must be a non-empty string`
  );
}


function validateManifest(
  manifest,
  filename
) {
  assert(
    manifest &&
    typeof manifest ===
      "object",
    `${filename}: manifest must be an object`
  );

  assertString(
    manifest.exportName,
    `${filename}.exportName`
  );

  const activity =
    manifest.activity;

  assert(
    activity &&
    typeof activity ===
      "object",
    `${filename}.activity is required`
  );

  assertString(
    activity.id,
    `${filename}.activity.id`
  );

  assert(
    Number.isInteger(
      activity.version
    ) &&
    activity.version >
      0,
    `${filename}.activity.version must be a positive integer`
  );

  assertString(
    activity.mechanic,
    `${filename}.activity.mechanic`
  );

  assertString(
    activity.ageBand,
    `${filename}.activity.ageBand`
  );

  assert(
    Array.isArray(
      activity.options
    ) &&
    activity.options.length >=
      2,
    `${filename}.activity.options must contain at least two choices`
  );

  const correctCount =
    activity.options.filter(
      option =>
        option.correct ===
        true
    ).length;

  assert(
    correctCount ===
      1,
    `${filename}: tap-choice activity must have exactly one correct option`
  );

  assert(
    activity.wellbeing &&
    activity.wellbeing.usesCountdownPressure ===
      false &&
    activity.wellbeing.usesLossAversion ===
      false &&
    activity.wellbeing.usesStreakPressure ===
      false &&
    activity.wellbeing.usesInfinitePlay ===
      false &&
    activity.wellbeing.usesBehaviouralAds ===
      false,
    `${filename}: wellbeing guardrails must remain disabled`
  );

  assert(
    activity.provenance &&
    activity.provenance.type ===
      "original" &&
    activity.provenance.creator ===
      "HIBEYA" &&
    activity.provenance.originalityReviewed ===
      true,
    `${filename}: original HIBEYA provenance review is required`
  );

  const catalogue =
    manifest.catalogue;

  assert(
    catalogue &&
    typeof catalogue ===
      "object",
    `${filename}.catalogue is required`
  );

  assertString(
    catalogue.blueprintId,
    `${filename}.catalogue.blueprintId`
  );

  assertString(
    catalogue.implementationKey,
    `${filename}.catalogue.implementationKey`
  );

  assert(
    Array.isArray(
      catalogue.ageBands
    ) &&
    catalogue.ageBands.length >
      0,
    `${filename}.catalogue.ageBands is required`
  );

  assert(
    catalogue.ageBands.includes(
      activity.ageBand
    ),
    `${filename}: primary activity ageBand must be present in catalogue.ageBands`
  );

  const insights =
    manifest.learningInsights;

  assert(
    insights &&
    Array.isArray(
      insights.objectives
    ),
    `${filename}.learningInsights.objectives is required`
  );
}


function listManifests() {
  if (
    !fs.existsSync(
      manifestRoot
    )
  ) {
    fail(
      `Manifest directory not found: ${manifestRoot}`
    );
  }

  return fs
    .readdirSync(
      manifestRoot
    )
    .filter(
      file =>
        file.endsWith(
          ".json"
        )
    )
    .sort();
}


const manifestFiles =
  listManifests();

assert(
  manifestFiles.length >
    0,
  "No activity manifests found"
);


const manifests =
  manifestFiles.map(
    filename => {
      const fullPath =
        path.join(
          manifestRoot,
          filename
        );

      const manifest =
        readJson(
          fullPath
        );

      validateManifest(
        manifest,
        filename
      );

      return {
        filename,
        manifest
      };
    }
  );


const activityIds =
  manifests.map(
    item =>
      item.manifest
        .activity
        .id
  );


assert(
  new Set(
    activityIds
  ).size ===
    activityIds.length,
  "Duplicate activity IDs are not allowed"
);


const exportNames =
  manifests.map(
    item =>
      item.manifest
        .exportName
  );


assert(
  new Set(
    exportNames
  ).size ===
    exportNames.length,
  "Duplicate export names are not allowed"
);


function jsonTs(
  value
) {
  return JSON.stringify(
    value,
    null,
    2
  );
}


function activitySource(
  manifest
) {
  return `import {
  ActivitySchema,
  type ActivityContent
} from "@akal-budi/content-schema";


const activity =
${jsonTs(manifest.activity)}
  satisfies ActivityContent;


export const ${manifest.exportName} =
  ActivitySchema.parse(
    activity
  );
`;
}


function catalogueSource() {
  const rows =
    manifests.map(
      ({ manifest }) => {
        const c =
          manifest.catalogue;

        return `    {
      id:
        ${JSON.stringify(manifest.activity.id)},

      blueprintId:
        ${JSON.stringify(c.blueprintId)},

      version:
        ${manifest.activity.version},

      enabled:
        ${Boolean(c.enabled)},

      ageBands:
        ${jsonTs(c.ageBands).replace(/\n/g, "\n        ")},

      titleMs:
        ${JSON.stringify(c.titleMs)},

      titleEn:
        ${JSON.stringify(c.titleEn)},

      implementationKey:
        ${JSON.stringify(c.implementationKey)}
    }`;
      }
    )
    .join(
      ",\n\n"
    );

  return `import {
  activityBlueprints,
  type AgeBand,
  type ActivityBlueprint
} from "@akal-budi/content-architecture";


export interface PlayableActivity {
  id: string;

  blueprintId: string;

  version: number;

  enabled: boolean;

  ageBands:
    readonly AgeBand[];

  titleMs: string;

  titleEn: string;

  implementationKey:
    string;
}


export interface ResolvedPlayableActivity
  extends PlayableActivity {
  blueprint:
    ActivityBlueprint;
}


export const playableActivities:
  readonly PlayableActivity[] = [

${rows}

  ];


export function getPlayableActivity(
  activityId: string
): ResolvedPlayableActivity | null {

  const activity =
    playableActivities.find(
      item =>
        item.id ===
        activityId
    );


  if (!activity) {
    return null;
  }


  const blueprint =
    activityBlueprints.find(
      item =>
        item.id ===
        activity.blueprintId
    );


  if (!blueprint) {
    return null;
  }


  return {
    ...activity,
    blueprint
  };
}


export function getPlayableActivitiesForAgeBand(
  ageBand: AgeBand
): ResolvedPlayableActivity[] {

  return playableActivities
    .filter(
      activity =>
        activity.enabled &&
        activity
          .ageBands
          .includes(
            ageBand
          )
    )
    .map(
      activity =>
        getPlayableActivity(
          activity.id
        )
    )
    .filter(
      (
        activity
      ): activity is ResolvedPlayableActivity =>
        activity !==
        null
    );
}
`;
}


function contentIndexSource() {
  const activityExports =
    manifests.map(
      ({ manifest }) =>
        `export {
  ${manifest.exportName}
} from "./activities/${manifest.activity.id}";`
    )
    .join(
      "\n\n"
    );

  return `${activityExports}


export {
  getPlayableActivitiesForAgeBand,
  getPlayableActivity,
  playableActivities
} from "./catalogue";


export {
  validatePlayableCatalogue
} from "./validateCatalogue";


export type {
  PlayableActivity,
  ResolvedPlayableActivity
} from "./catalogue";


export type {
  CatalogueIssue
} from "./validateCatalogue";
`;
}


function registrySource() {
  const imports =
    manifests
      .map(
        ({ manifest }) =>
          `  ${manifest.exportName}`
      )
      .join(
        ",\n"
      );

  const union =
    manifests
      .map(
        ({ manifest }) =>
          `typeof ${manifest.exportName}`
      )
      .join(
        " |\n  "
      );

  const implementations =
    manifests
      .map(
        ({ manifest }) =>
          `    {
      activityId:
        ${JSON.stringify(manifest.activity.id)},

      implementationKey:
        ${JSON.stringify(manifest.catalogue.implementationKey)},

      activity:
        ${manifest.exportName}
    }`
      )
      .join(
        ",\n\n"
      );

  return `import {
${imports}
} from "@akal-budi/content-library";


type SupportedActivity =
  ${union};


export interface ActivityImplementation {
  activityId: string;

  implementationKey:
    string;

  activity:
    SupportedActivity;
}


const implementations:
  readonly ActivityImplementation[] = [

${implementations}

  ];


export function getActivityImplementation(
  activityId: string,
  implementationKey: string
): ActivityImplementation | null {

  return (
    implementations.find(
      implementation =>
        implementation
          .activityId ===
          activityId &&
        implementation
          .implementationKey ===
          implementationKey
    ) ??
    null
  );
}


export function hasActivityImplementation(
  activityId: string,
  implementationKey: string
): boolean {

  return implementations.some(
    implementation =>
      implementation
        .activityId ===
        activityId &&
      implementation
        .implementationKey ===
        implementationKey
  );
}
`;
}


function learningMetadataSource() {
  const entries =
    manifests
      .map(
        ({ manifest }) => {
          const insights =
            manifest.learningInsights;

          const malaysia =
            Array.isArray(
              insights.malaysiaElements
            ) &&
            insights.malaysiaElements.length >
              0
              ? `,\n\n      malaysiaElements:\n        ${jsonTs(insights.malaysiaElements).replace(/\n/g, "\n        ")}`
              : "";

          return `    {
      activityId:
        ${JSON.stringify(manifest.activity.id)},

      objectives:
        ${jsonTs(insights.objectives).replace(/\n/g, "\n        ")}${malaysia}
    }`;
        }
      )
      .join(
        ",\n\n"
      );

  return `import type {
  ActivityLearningMetadata
} from "./types";


export const activityLearningMetadata:
  readonly ActivityLearningMetadata[] = [

${entries}

  ];
`;
}


const outputs =
  new Map();


for (
  const {
    manifest
  }
  of manifests
) {
  outputs.set(
    path.join(
      repoRoot,
      "packages",
      "content-library",
      "src",
      "activities",
      `${manifest.activity.id}.ts`
    ),
    activitySource(
      manifest
    )
  );
}


outputs.set(
  path.join(
    repoRoot,
    "packages",
    "content-library",
    "src",
    "catalogue.ts"
  ),
  catalogueSource()
);


outputs.set(
  path.join(
    repoRoot,
    "packages",
    "content-library",
    "src",
    "index.ts"
  ),
  contentIndexSource()
);


outputs.set(
  path.join(
    repoRoot,
    "apps",
    "learner-web",
    "src",
    "features",
    "play",
    "activityRegistry.ts"
  ),
  registrySource()
);


outputs.set(
  path.join(
    repoRoot,
    "packages",
    "learning-insights",
    "src",
    "activityMetadata.ts"
  ),
  learningMetadataSource()
);


const checkOnly =
  process.argv.includes(
    "--check"
  );


let mismatch =
  false;


for (
  const [
    filePath,
    content
  ]
  of outputs
) {
  const normalised =
    content
      .trimEnd() +
    "\n";


  if (checkOnly) {
    const existing =
      fs.existsSync(
        filePath
      )
        ? fs.readFileSync(
            filePath,
            "utf8"
          )
        : null;


    if (
      existing !==
      normalised
    ) {
      mismatch =
        true;

      console.error(
        `OUT OF DATE: ${path.relative(repoRoot, filePath)}`
      );
    }

    continue;
  }


  fs.mkdirSync(
    path.dirname(
      filePath
    ),
    {
      recursive:
        true
    }
  );


  fs.writeFileSync(
    filePath,
    normalised,
    "utf8"
  );


  console.log(
    `GENERATED: ${path.relative(repoRoot, filePath)}`
  );
}


if (
  checkOnly &&
  mismatch
) {
  process.exit(2);
}


if (checkOnly) {
  console.log(
    "CONTENT COMPILER CHECK: PASS"
  );
} else {
  console.log(
    `CONTENT COMPILER: ${manifests.length} manifests compiled`
  );
}
