import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const manifestRoot =
  path.join(
    root,
    "assets",
    "manifests"
  );

const generatedPath =
  path.join(
    root,
    "packages",
    "assets",
    "src",
    "generated",
    "commercialRegistry.generated.ts"
  );

const approved = [];

for (
  const file
  of fs.readdirSync(
    manifestRoot
  )
    .filter(
      file =>
        file.endsWith(
          ".json"
        )
    )
    .sort()
) {
  const manifest =
    JSON.parse(
      fs.readFileSync(
        path.join(
          manifestRoot,
          file
        ),
        "utf8"
      )
    );

  if (
    manifest.commercialReady ===
    true
  ) {
    approved.push(
      manifest.id
    );
  }
}

if (
  !fs.existsSync(
    generatedPath
  )
) {
  console.error(
    "COMMERCIAL REGISTRY VALIDATION: generated registry missing"
  );

  process.exit(1);
}

const generated =
  fs.readFileSync(
    generatedPath,
    "utf8"
  );

for (
  const id
  of approved
) {
  if (
    !generated.includes(
      JSON.stringify(
        id
      )
    )
  ) {
    console.error(
      `COMMERCIAL REGISTRY VALIDATION: approved asset missing from runtime registry: ${id}`
    );

    process.exit(1);
  }
}

const declaredIds =
  [
    ...generated.matchAll(
      /^\s*"([^"]+)": \{$/gm
    )
  ]
    .map(
      match =>
        match[1]
    );

const unexpected =
  declaredIds.filter(
    id =>
      !approved.includes(
        id
      )
  );

if (
  unexpected.length >
  0
) {
  console.error(
    `COMMERCIAL REGISTRY VALIDATION: unapproved assets leaked into runtime registry: ${unexpected.join(", ")}`
  );

  process.exit(1);
}

console.log(
  `COMMERCIAL REGISTRY VALIDATION: PASS (${approved.length} approved assets)`
);
