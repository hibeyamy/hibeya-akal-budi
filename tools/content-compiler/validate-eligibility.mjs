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

const manifestDir =
  path.join(
    root,
    "content",
    "activity-manifests"
  );

const failures =
  [];


function fail(
  message
) {
  failures.push(
    message
  );
}


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


if (
  !fs.existsSync(
    graphPath
  )
) {
  fail(
    "Canonical skill graph is missing."
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


const graph =
  fs.existsSync(
    graphPath
  )
    ? readJson(
        graphPath
      )
    : {
        skills: [],
        prerequisites: []
      };


const skills =
  Array.isArray(
    graph.skills
  )
    ? graph.skills
    : [];

const prerequisites =
  Array.isArray(
    graph.prerequisites
  )
    ? graph.prerequisites
    : [];


const skillIds =
  new Set(
    skills.map(
      skill =>
        skill.id
    )
  );


for (
  const edge
  of prerequisites
) {
  if (
    ![
      "required",
      "recommended"
    ].includes(
      edge.strength
    )
  ) {
    fail(
      `Invalid prerequisite strength for ${edge.skillId}: ${edge.strength}`
    );
  }

  if (
    !skillIds.has(
      edge.skillId
    )
  ) {
    fail(
      `Unknown prerequisite target skill: ${edge.skillId}`
    );
  }

  if (
    !skillIds.has(
      edge.prerequisiteSkillId
    )
  ) {
    fail(
      `Unknown prerequisite source skill: ${edge.prerequisiteSkillId}`
    );
  }
}


const manifests =
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
          file => ({
            file,
            manifest:
              readJson(
                path.join(
                  manifestDir,
                  file
                )
              )
          })
        )
    : [];


for (
  const {
    file,
    manifest
  }
  of manifests
) {
  const mappings =
    Array.isArray(
      manifest.skillMappings
    )
      ? manifest.skillMappings
      : [];

  if (
    mappings.length ===
      0
  ) {
    fail(
      `${file}: skillMappings[] must not be empty`
    );

    continue;
  }

  const mappedIds =
    mappings.map(
      mapping =>
        mapping.skillId
    );

  if (
    new Set(
      mappedIds
    ).size !==
      mappedIds.length
  ) {
    fail(
      `${file}: duplicate skill mappings are not allowed`
    );
  }

  if (
    !mappings.some(
      mapping =>
        mapping.role ===
          "primary"
    )
  ) {
    fail(
      `${file}: at least one primary skill mapping is required`
    );
  }

  const activitySkills =
    Array.isArray(
      manifest.activity?.skills
    )
      ? new Set(
          manifest.activity.skills
        )
      : new Set();

  for (
    const mapping
    of mappings
  ) {
    if (
      !skillIds.has(
        mapping.skillId
      )
    ) {
      fail(
        `${file}: unknown mapped skill ${mapping.skillId}`
      );
    }

    if (
      !activitySkills.has(
        mapping.skillId
      )
    ) {
      fail(
        `${file}: skillMappings contains ${mapping.skillId} but activity.skills does not`
      );
    }
  }
}


// Reachability guard for REQUIRED prerequisite edges.
// An enabled activity teaching a primary target skill must have a possible
// earlier enabled activity in at least one shared age band that teaches each
// required prerequisite skill.
for (
  const {
    file,
    manifest
  }
  of manifests
) {
  if (
    manifest.catalogue?.enabled !==
      true
  ) {
    continue;
  }

  const primarySkills =
    (manifest.skillMappings ??
      [])
      .filter(
        mapping =>
          mapping.role ===
            "primary"
      )
      .map(
        mapping =>
          mapping.skillId
      );

  const required =
    prerequisites.filter(
      edge =>
        edge.strength ===
          "required" &&
        primarySkills.includes(
          edge.skillId
        )
    );

  for (
    const edge
    of required
  ) {
    const targetBands =
      manifest.catalogue?.ageBands ??
      [];

    const targetSequence =
      manifest.catalogue?.sequence;

    const sourceExists =
      manifests.some(
        candidate => {
          if (
            candidate.manifest.catalogue?.enabled !==
              true
          ) {
            return false;
          }

          if (
            !Number.isInteger(
              candidate.manifest.catalogue?.sequence
            ) ||
            candidate.manifest.catalogue.sequence >=
              targetSequence
          ) {
            return false;
          }

          const sharedBand =
            (
              candidate.manifest.catalogue?.ageBands ??
              []
            ).some(
              ageBand =>
                targetBands.includes(
                  ageBand
                )
            );

          if (!sharedBand) {
            return false;
          }

          return (
            candidate.manifest.skillMappings ??
            []
          ).some(
            mapping =>
              mapping.skillId ===
                edge.prerequisiteSkillId
          );
        }
      );

    if (!sourceExists) {
      fail(
        `${file}: required prerequisite ${edge.prerequisiteSkillId} for ${edge.skillId} has no earlier enabled teaching activity in a shared age band`
      );
    }
  }
}


if (
  failures.length >
    0
) {
  console.error(
    "CONTENT ELIGIBILITY VALIDATION: FAILED"
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
  `CONTENT ELIGIBILITY VALIDATION: PASS (${manifests.length} manifests, ${prerequisites.length} prerequisite edges)`
);
