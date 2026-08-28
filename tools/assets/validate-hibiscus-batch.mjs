import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const ids = [
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

const failures = [];

function hash(file) {
  return crypto
    .createHash("sha256")
    .update(fs.readFileSync(file))
    .digest("hex");
}

for (const id of ids) {
  const master =
    path.join(root,"assets","masters",`${id}.svg`);

  const exported =
    path.join(root,"assets","exports",`${id}.svg`);

  const runtime =
    path.join(root,"packages","assets","src","generated",`${id}.svg`);

  const manifestPath =
    path.join(root,"assets","manifests",`${id}.json`);

  for (const file of [master,exported,runtime,manifestPath]) {
    if (!fs.existsSync(file)) {
      failures.push(`${id}: missing ${path.relative(root,file)}`);
    }
  }

  if (
    fs.existsSync(master) &&
    fs.existsSync(exported) &&
    fs.existsSync(runtime)
  ) {
    if (
      new Set(
        [
          hash(master),
          hash(exported),
          hash(runtime)
        ]
      ).size !==
      1
    ) {
      failures.push(
        `${id}: master/export/runtime hashes differ`
      );
    }

    const svg =
      fs.readFileSync(
        master,
        "utf8"
      );

    if (
      /<script\b/i.test(svg) ||
      /\bon[a-z]+\s*=/i.test(svg) ||
      /<foreignObject\b/i.test(svg)
    ) {
      failures.push(
        `${id}: unsafe SVG content`
      );
    }
  }

  if (fs.existsSync(manifestPath)) {
    const manifest =
      JSON.parse(
        fs.readFileSync(
          manifestPath,
          "utf8"
        )
      );

    if (manifest.status !== "review")
      failures.push(`${id}: expected review status`);

    if (manifest.commercialReady !== false)
      failures.push(`${id}: candidate must not self-approve`);

    if (manifest.culturalReviewRequired !== true)
      failures.push(`${id}: cultural review must be required`);

    if (manifest.culturalReviewed !== false)
      failures.push(`${id}: cultural review must remain pending before manual approval`);
  }
}

if (failures.length) {
  for (const failure of failures) {
    console.error(`HIBISCUS BATCH ERROR: ${failure}`);
  }

  process.exit(1);
}

console.log(
  "HIBISCUS BATCH VALIDATION: PASS (3 review candidates)"
);
