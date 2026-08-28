import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root =
  process.cwd();

const graphPath =
  path.join(
    root,
    "content",
    "curriculum",
    "skill-graph.json"
  );

const policyPath =
  path.join(
    root,
    "content",
    "curriculum",
    "coverage-policy.json"
  );

const manifestDirectory =
  path.join(
    root,
    "content",
    "activity-manifests"
  );

function readJson(
  file
) {
  return JSON.parse(
    fs.readFileSync(
      file,
      "utf8"
    )
  );
}

const graph =
  readJson(
    graphPath
  );

const policy =
  readJson(
    policyPath
  );

const minimum =
  policy
    .activeSkillPolicy
    .minimumEnabledPrimaryActivities;

const target =
  policy
    .activeSkillPolicy
    .targetEnabledPrimaryActivities;

if (
  !Number.isInteger(
    minimum
  ) ||
  minimum < 0 ||
  !Number.isInteger(
    target
  ) ||
  target < minimum
) {
  throw new Error(
    "Invalid curriculum coverage policy."
  );
}

const activeSkills =
  new Map(
    graph.skills
      .filter(
        skill =>
          skill.active
      )
      .map(
        skill => [
          skill.id,
          skill
        ]
      )
  );

const manifests =
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
          file => ({
            file,
            manifest:
              readJson(
                path.join(
                  manifestDirectory,
                  file
                )
              )
          })
        )
    : [];

const coverage =
  new Map(
    [...activeSkills.keys()]
      .map(
        skillId => [
          skillId,
          {
            enabledPrimary:
              [],
            draftPrimary:
              []
          }
        ]
      )
  );

const errors = [];

for (
  const {
    file,
    manifest
  } of manifests
) {
  const activityId =
    manifest.activity?.id ??
      file;

  const enabled =
    manifest.catalogue?.enabled ===
      true;

  const mappings =
    Array.isArray(
      manifest.skillMappings
    )
      ? manifest.skillMappings
      : [];

  for (
    const mapping of mappings
  ) {
    if (
      mapping.role !==
        "primary"
    ) {
      continue;
    }

    if (
      !activeSkills.has(
        mapping.skillId
      )
    ) {
      errors.push(
        `${activityId}: primary skill is unknown or inactive: ${mapping.skillId}`
      );

      continue;
    }

    const entry =
      coverage.get(
        mapping.skillId
      );

    if (enabled) {
      entry.enabledPrimary.push(
        activityId
      );
    }
    else {
      entry.draftPrimary.push(
        activityId
      );
    }
  }
}

for (
  const [
    skillId,
    entry
  ] of coverage
) {
  const count =
    entry.enabledPrimary.length;

  const state =
    count < minimum
      ? "FAIL"
      : count < target
        ? "DEPTH-GAP"
        : "TARGET";

  console.log(
    [
      state,
      skillId,
      `enabled-primary=${count}`,
      `draft-primary=${entry.draftPrimary.length}`,
      `minimum=${minimum}`,
      `target=${target}`
    ].join(
      " | "
    )
  );

  if (
    count < minimum
  ) {
    errors.push(
      `${skillId}: ${count} enabled primary activities; minimum is ${minimum}`
    );
  }
}

if (
  errors.length > 0
) {
  console.error(
    ""
  );

  for (
    const error of errors
  ) {
    console.error(
      `COVERAGE ERROR: ${error}`
    );
  }

  process.exit(1);
}

console.log(
  "CONTENT COVERAGE VALIDATION: PASS"
);
