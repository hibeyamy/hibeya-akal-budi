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

const blocked = [];

for (
  const file
  of files
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
    manifest.role ===
      "learner-core" &&
    manifest.commercialReady !==
      true
  ) {
    blocked.push(
      manifest.id
    );
  }
}

if (
  blocked.length > 0
) {
  console.error(
    "COMMERCIAL ASSET GATE: BLOCKED"
  );

  console.error(
    "Replace/review these learner-core assets before commercial release:"
  );

  for (
    const id
    of blocked
  ) {
    console.error(
      `- ${id}`
    );
  }

  process.exit(1);
}

console.log(
  "COMMERCIAL ASSET GATE: PASS"
);
