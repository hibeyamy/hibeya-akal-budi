import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const [
  ,
  ,
  command,
  ...args
] =
  process.argv;


const repoRoot =
  process.cwd();

const queuePath =
  path.join(
    repoRoot,
    "content",
    "curriculum",
    "review-queue.json"
  );


const queue =
  JSON.parse(
    fs.readFileSync(
      queuePath,
      "utf8"
    )
  );


function save() {
  fs.writeFileSync(
    queuePath,
    JSON.stringify(
      queue,
      null,
      2
    ) +
    "\n",
    "utf8"
  );
}


if (
  command ===
    "add"
) {
  const [
    mappingId,
    activityId,
    curriculumVersionId,
    standardId
  ] =
    args;


  if (
    !mappingId ||
    !activityId ||
    !curriculumVersionId ||
    !standardId
  ) {
    console.error(
      "Usage: review-mapping.mjs add <mapping-id> <activity-id> <curriculum-version-id> <standard-id>"
    );

    process.exit(1);
  }


  if (
    queue.items.some(
      item =>
        item.id ===
        mappingId
    )
  ) {
    console.error(
      `Review item already exists: ${mappingId}`
    );

    process.exit(1);
  }


  queue.items.push({
    id:
      mappingId,

    activityId,

    curriculumVersionId,

    standardId,

    status:
      "draft",

    reviewer:
      null,

    reviewedAt:
      null,

    notes:
      null
  });


  save();

  console.log(
    `REVIEW ITEM CREATED: ${mappingId}`
  );

  process.exit(0);
}


if (
  command ===
    "approve"
) {
  const [
    mappingId,
    reviewer
  ] =
    args;


  if (
    !mappingId ||
    !reviewer
  ) {
    console.error(
      "Usage: review-mapping.mjs approve <mapping-id> <reviewer>"
    );

    process.exit(1);
  }


  const item =
    queue.items.find(
      candidate =>
        candidate.id ===
        mappingId
    );


  if (!item) {
    console.error(
      `Unknown review item: ${mappingId}`
    );

    process.exit(1);
  }


  item.status =
    "approved";

  item.reviewer =
    reviewer;

  item.reviewedAt =
    new Date()
      .toISOString();


  save();

  console.log(
    `REVIEW ITEM APPROVED: ${mappingId}`
  );

  process.exit(0);
}


if (
  command ===
    "list"
) {
  console.log(
    JSON.stringify(
      queue.items,
      null,
      2
    )
  );

  process.exit(0);
}


console.error(
  "Commands: add | approve | list"
);

process.exit(1);
