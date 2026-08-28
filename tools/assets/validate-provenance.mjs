import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const policyPath =
  path.join(
    root,
    "assets",
    "provenance-policy.json"
  );

const manifestRoot =
  path.join(
    root,
    "assets",
    "manifests"
  );

const policy =
  JSON.parse(
    fs.readFileSync(
      policyPath,
      "utf8"
    )
  );

const failures = [];

function fail(message) {
  failures.push(message);
  console.error(
    `ASSET PROVENANCE ERROR: ${message}`
  );
}

const files =
  fs.readdirSync(
    manifestRoot
  )
    .filter(
      file =>
        file.endsWith(
          ".json"
        )
    );

if (
  files.length === 0
) {
  fail(
    "No asset provenance manifests exist"
  );
}

const seen =
  new Set();

for (
  const file
  of files
) {
  const full =
    path.join(
      manifestRoot,
      file
    );

  let manifest;

  try {
    manifest =
      JSON.parse(
        fs.readFileSync(
          full,
          "utf8"
        )
      );
  }
  catch (error) {
    fail(
      `${file}: invalid JSON`
    );

    continue;
  }

  const required = [
    "schemaVersion",
    "id",
    "status",
    "role",
    "currentRepresentation",
    "sourceType",
    "creator",
    "sourceFile",
    "commercialRightsConfirmed",
    "originalityReviewed",
    "childSafetyReviewed",
    "commercialReady"
  ];

  for (
    const field
    of required
  ) {
    if (
      manifest[field] ===
      undefined ||
      manifest[field] ===
      null ||
      manifest[field] ===
      ""
    ) {
      fail(
        `${file}: missing ${field}`
      );
    }
  }

  if (
    seen.has(
      manifest.id
    )
  ) {
    fail(
      `${file}: duplicate asset id ${manifest.id}`
    );
  }

  seen.add(
    manifest.id
  );

  if (
    file !==
    `${manifest.id}.json`
  ) {
    fail(
      `${file}: filename must match asset id`
    );
  }

  if (
    !policy.allowedSourceTypes.includes(
      manifest.sourceType
    )
  ) {
    fail(
      `${file}: unsupported sourceType ${manifest.sourceType}`
    );
  }

  if (
    manifest.status ===
      "production" &&
    manifest.commercialReady !==
      true
  ) {
    fail(
      `${file}: production asset must be commercialReady`
    );
  }

  if (
    manifest.commercialReady ===
      true
  ) {
    for (
      const check
      of policy.requiredProductionChecks
    ) {
      if (
        manifest[check] !==
        true
      ) {
        fail(
          `${file}: commercial asset requires ${check}=true`
        );
      }
    }

    if (
      !policy.commercialSourceTypes.includes(
        manifest.sourceType
      )
    ) {
      fail(
        `${file}: source type is not approved for commercial release`
      );
    }

    if (
      manifest.culturalReviewRequired ===
        true &&
      manifest.culturalReviewed !==
        true
    ) {
      fail(
        `${file}: required cultural review is incomplete`
      );
    }
  }
}

if (
  failures.length > 0
) {
  process.exit(1);
}

console.log(
  `ASSET PROVENANCE VALIDATION: PASS (${files.length} manifests)`
);
