import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root =
  process.cwd();

const manifestDir =
  path.join(
    root,
    "content",
    "activity-manifests"
  );

const failures = [];

function fail(message) {
  failures.push(
    message
  );
}

if (
  !fs.existsSync(
    manifestDir
  )
) {
  fail(
    "Activity manifest directory is missing."
  );
}

const entries =
  fs.existsSync(
    manifestDir
  )
    ? fs.readdirSync(
        manifestDir
      )
        .filter(
          file =>
            file.endsWith(
              ".json"
            )
        )
        .sort()
        .map(
          file => {
            const manifest =
              JSON.parse(
                fs.readFileSync(
                  path.join(
                    manifestDir,
                    file
                  ),
                  "utf8"
                )
              );

            return {
              file,
              id:
                manifest.activity?.id,
              enabled:
                manifest.catalogue?.enabled ===
                  true,
              sequence:
                manifest.catalogue?.sequence,
              ageBands:
                Array.isArray(
                  manifest.catalogue?.ageBands
                )
                  ? manifest.catalogue.ageBands
                  : []
            };
          }
        )
    : [];

for (
  const entry
  of entries
) {
  if (
    !Number.isInteger(
      entry.sequence
    ) ||
    entry.sequence <=
      0
  ) {
    fail(
      `${entry.file}: catalogue.sequence must be a positive integer`
    );
  }

  if (
    entry.ageBands.length ===
      0
  ) {
    fail(
      `${entry.file}: catalogue.ageBands must contain at least one age band`
    );
  }
}

for (
  let leftIndex = 0;
  leftIndex <
    entries.length;
  leftIndex +=
    1
) {
  for (
    let rightIndex =
      leftIndex +
      1;
    rightIndex <
      entries.length;
    rightIndex +=
      1
  ) {
    const left =
      entries[leftIndex];

    const right =
      entries[rightIndex];

    if (
      left.sequence !==
        right.sequence
    ) {
      continue;
    }

    const overlapping =
      left.ageBands.filter(
        ageBand =>
          right.ageBands.includes(
            ageBand
          )
      );

    if (
      overlapping.length >
      0
    ) {
      fail(
        `${left.file} and ${right.file}: duplicate sequence ${left.sequence} for overlapping age band(s): ${overlapping.join(", ")}`
      );
    }
  }
}

if (
  failures.length >
    0
) {
  console.error(
    "CONTENT SEQUENCING VALIDATION: FAILED"
  );

  for (
    const failure
    of failures
  ) {
    console.error(
      `- ${failure}`
    );
  }

  process.exit(
    1
  );
}

console.log(
  `CONTENT SEQUENCING VALIDATION: PASS (${entries.length} manifests)`
);
