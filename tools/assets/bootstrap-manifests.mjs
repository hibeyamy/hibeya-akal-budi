import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const registryPath =
  path.join(
    root,
    "packages",
    "assets",
    "src",
    "index.ts"
  );

const manifestRoot =
  path.join(
    root,
    "assets",
    "manifests"
  );

if (!fs.existsSync(registryPath)) {
  console.error(
    `Asset registry missing: ${registryPath}`
  );

  process.exit(1);
}

fs.mkdirSync(
  manifestRoot,
  {
    recursive: true
  }
);

const source =
  fs.readFileSync(
    registryPath,
    "utf8"
  );

const pattern =
  /"([^"]+)"\s*:\s*\{[\s\S]*?\bid\s*:\s*"([^"]+)"[\s\S]*?\btype\s*:\s*"(emoji|image)"[\s\S]*?\bvalue\s*:\s*"([^"]*)"/g;

const found =
  new Map();

for (
  const match
  of source.matchAll(
    pattern
  )
) {
  const objectKey =
    match[1];

  const id =
    match[2];

  const type =
    match[3];

  const value =
    match[4];

  if (
    objectKey !== id
  ) {
    console.error(
      `Registry key/id mismatch: ${objectKey} != ${id}`
    );

    process.exit(1);
  }

  found.set(
    id,
    {
      id,
      type,
      value
    }
  );
}

if (
  found.size === 0
) {
  console.error(
    "No asset definitions could be detected in packages/assets/src/index.ts"
  );

  process.exit(1);
}

let created = 0;
let existing = 0;

for (
  const asset
  of found.values()
) {
  const target =
    path.join(
      manifestRoot,
      `${asset.id}.json`
    );

  if (
    fs.existsSync(
      target
    )
  ) {
    existing += 1;
    continue;
  }

  const manifest = {
    schemaVersion:
      1,

    id:
      asset.id,

    status:
      "prototype",

    role:
      "learner-core",

    currentRepresentation:
      asset.type ===
      "emoji"
        ? "emoji"
        : "legacy-image",

    sourceType:
      asset.type ===
      "emoji"
        ? "unicode-emoji"
        : "legacy-placeholder",

    creator:
      "legacy-system",

    sourceFile:
      "packages/assets/src/index.ts",

    sourceValue:
      asset.value,

    commercialRightsConfirmed:
      false,

    originalityReviewed:
      false,

    culturalReviewRequired:
      false,

    culturalReviewed:
      false,

    childSafetyReviewed:
      false,

    commercialReady:
      false,

    replacementRequiredForCommercialRelease:
      true,

    notes:
      "Automatically classified as a prototype asset during Phase 007A. Replace through the HIBEYA original asset pipeline before commercial release."
  };

  fs.writeFileSync(
    target,
    JSON.stringify(
      manifest,
      null,
      2
    ) + "\n",
    "utf8"
  );

  created += 1;
}

console.log(
  `ASSET BOOTSTRAP: ${found.size} registry assets; ${created} manifests created; ${existing} preserved`
);
