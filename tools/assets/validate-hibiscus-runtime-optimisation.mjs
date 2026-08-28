import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import sharp from "sharp";

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
  const manifestPath =
    path.join(root,"assets","manifests",`${id}.json`);

  const manifest =
    JSON.parse(
      fs.readFileSync(manifestPath,"utf8")
    );

  const master =
    path.join(root,"assets","masters",`${id}.png`);

  const runtime =
    path.join(root,"packages","assets","src","generated",`${id}.webp`);

  if (!fs.existsSync(master)) {
    failures.push(`${id}: PNG master missing`);
    continue;
  }

  if (!fs.existsSync(runtime)) {
    failures.push(`${id}: WebP runtime missing`);
    continue;
  }

  if (
    manifest.runtime?.file !==
    `packages/assets/src/generated/${id}.webp`
  ) {
    failures.push(`${id}: manifest runtime path is not WebP`);
  }

  if (
    manifest.runtimeOptimisation?.sourceSha256 !==
    hash(master)
  ) {
    failures.push(`${id}: master hash mismatch`);
  }

  if (
    manifest.runtimeOptimisation?.runtimeSha256 !==
    hash(runtime)
  ) {
    failures.push(`${id}: runtime hash mismatch`);
  }

  const metadata =
    await sharp(runtime)
      .metadata();

  if (metadata.format !== "webp") {
    failures.push(`${id}: runtime is not WebP`);
  }

  if (
    (metadata.width ?? 0) > 640 ||
    (metadata.height ?? 0) > 640
  ) {
    failures.push(`${id}: runtime dimensions exceed 640px`);
  }

  if (
    fs.statSync(runtime).size >
    450 * 1024
  ) {
    failures.push(`${id}: runtime exceeds 450KB`);
  }

  if (
    manifest.status !== "production" ||
    manifest.commercialReady !== true
  ) {
    failures.push(`${id}: optimisation changed approval state`);
  }
}

if (failures.length) {
  for (const failure of failures) {
    console.error(`RUNTIME OPTIMISATION ERROR: ${failure}`);
  }

  process.exit(1);
}

console.log(
  "RUNTIME OPTIMISATION VALIDATION: PASS"
);
