import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const repoRoot =
  process.cwd();


function fail(
  message
) {
  console.error(
    `CURRICULUM VALIDATION ERROR: ${message}`
  );

  process.exitCode =
    1;
}


function readJson(
  relativePath
) {
  return JSON.parse(
    fs.readFileSync(
      path.join(
        repoRoot,
        relativePath
      ),
      "utf8"
    )
  );
}


const graph =
  readJson(
    "content/curriculum/skill-graph.json"
  );


if (
  !Array.isArray(
    graph.skills
  )
) {
  fail(
    "skill-graph.json must contain skills[]"
  );
}


if (
  !Array.isArray(
    graph.prerequisites
  )
) {
  fail(
    "skill-graph.json must contain prerequisites[]"
  );
}


const skillIds =
  graph.skills.map(
    skill =>
      skill.id
  );


const skillIdSet =
  new Set(
    skillIds
  );


if (
  skillIdSet.size !==
  skillIds.length
) {
  fail(
    "Duplicate skill IDs are not allowed."
  );
}


for (
  const edge
  of graph.prerequisites
) {
  if (
    !skillIdSet.has(
      edge.skillId
    )
  ) {
    fail(
      `Unknown skillId in prerequisite: ${edge.skillId}`
    );
  }


  if (
    !skillIdSet.has(
      edge.prerequisiteSkillId
    )
  ) {
    fail(
      `Unknown prerequisiteSkillId: ${edge.prerequisiteSkillId}`
    );
  }


  if (
    edge.skillId ===
    edge.prerequisiteSkillId
  ) {
    fail(
      `Self prerequisite is forbidden: ${edge.skillId}`
    );
  }
}


/*
 * Cycle detection.
 */
const adjacency =
  new Map();


for (
  const skillId
  of skillIds
) {
  adjacency.set(
    skillId,
    []
  );
}


for (
  const edge
  of graph.prerequisites
) {
  adjacency
    .get(
      edge.prerequisiteSkillId
    )
    .push(
      edge.skillId
    );
}


const visiting =
  new Set();

const visited =
  new Set();


function visit(
  skillId
) {
  if (
    visiting.has(
      skillId
    )
  ) {
    fail(
      `Skill prerequisite cycle detected at ${skillId}`
    );

    return;
  }


  if (
    visited.has(
      skillId
    )
  ) {
    return;
  }


  visiting.add(
    skillId
  );


  for (
    const next
    of adjacency.get(
      skillId
    ) ??
    []
  ) {
    visit(
      next
    );
  }


  visiting.delete(
    skillId
  );

  visited.add(
    skillId
  );
}


for (
  const skillId
  of skillIds
) {
  visit(
    skillId
  );
}


/*
 * Validate every activity manifest against the canonical skill graph.
 */
const manifestDir =
  path.join(
    repoRoot,
    "content",
    "activity-manifests"
  );


const manifestFiles =
  fs.readdirSync(
    manifestDir
  )
    .filter(
      filename =>
        filename.endsWith(
          ".json"
        )
    )
    .sort();


for (
  const filename
  of manifestFiles
) {
  const manifest =
    readJson(
      path.join(
        "content",
        "activity-manifests",
        filename
      )
    );


  if (
    !Array.isArray(
      manifest.skillMappings
    )
  ) {
    fail(
      `${filename}: skillMappings[] is required`
    );

    continue;
  }


  if (
    !Array.isArray(
      manifest.curriculumMappings
    )
  ) {
    fail(
      `${filename}: curriculumMappings[] is required`
    );
  }


  for (
    const mapping
    of manifest.skillMappings
  ) {
    if (
      !skillIdSet.has(
        mapping.skillId
      )
    ) {
      fail(
        `${filename}: unknown skill ${mapping.skillId}`
      );
    }


    if (
      ![
        "primary",
        "supporting"
      ].includes(
        mapping.role
      )
    ) {
      fail(
        `${filename}: invalid skill role ${mapping.role}`
      );
    }


    if (
      typeof mapping.weight !==
        "number" ||
      mapping.weight <=
        0 ||
      mapping.weight >
        1
    ) {
      fail(
        `${filename}: skill weight must be > 0 and <= 1`
      );
    }
  }


  /*
   * Curriculum mappings remain empty until a versioned,
   * source-verified curriculum pack exists.
   * Draft mappings may exist later, but must never pretend to
   * be verified without review metadata.
   */
  for (
    const mapping
    of manifest.curriculumMappings
  ) {
    if (
      mapping.reviewStatus ===
        "verified" &&
      (
        !mapping.reviewedBy ||
        !mapping.reviewedAt
      )
    ) {
      fail(
        `${filename}: verified curriculum mapping requires reviewedBy and reviewedAt`
      );
    }
  }
}


if (
  process.exitCode ===
  1
) {
  process.exit(1);
}


console.log(
  `CURRICULUM VALIDATION: PASS (${skillIds.length} skills, ${manifestFiles.length} manifests)`
);
