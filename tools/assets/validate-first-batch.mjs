import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow"
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
    path.join(root, "assets", "masters", `${id}.svg`);

  const exported =
    path.join(root, "assets", "exports", `${id}.svg`);

  const runtime =
    path.join(root, "packages", "assets", "src", "generated", `${id}.svg`);

  const manifest =
    path.join(root, "assets", "manifests", `${id}.json`);

  for (const file of [master, exported, runtime, manifest]) {
    if (!fs.existsSync(file)) {
      failures.push(`${id}: missing ${path.relative(root,file)}`);
    }
  }

  if (
    fs.existsSync(master) &&
    fs.existsSync(exported) &&
    fs.existsSync(runtime)
  ) {
    const hashes = [
      hash(master),
      hash(exported),
      hash(runtime)
    ];

    if (
      new Set(hashes).size !==
      1
    ) {
      failures.push(`${id}: master/export/runtime hashes differ`);
    }
  }

  if (fs.existsSync(manifest)) {
    const m =
      JSON.parse(
        fs.readFileSync(
          manifest,
          "utf8"
        )
      );

    if (m.sourceType !== "original-internal") {
      failures.push(`${id}: sourceType must be original-internal`);
    }

    if (m.status !== "review") {
      failures.push(`${id}: expected review status before human approval`);
    }

    if (m.commercialReady !== false) {
      failures.push(`${id}: must not self-approve commercialReady`);
    }
  }
}

if (failures.length) {
  for (const failure of failures) {
    console.error(`FIRST BATCH ERROR: ${failure}`);
  }

  process.exit(1);
}

console.log(
  "FIRST ORIGINAL ASSET BATCH: PASS (3 review candidates)"
);
