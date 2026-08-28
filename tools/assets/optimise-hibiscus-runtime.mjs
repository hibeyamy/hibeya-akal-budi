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

const MAX_EDGE = 640;
const WEBP_QUALITY = 82;
const TARGET_MAX_BYTES = 450 * 1024;

function sha256(file) {
  return crypto
    .createHash("sha256")
    .update(fs.readFileSync(file))
    .digest("hex");
}

for (const id of ids) {
  const manifestPath =
    path.join(root,"assets","manifests",`${id}.json`);

  if (!fs.existsSync(manifestPath)) {
    throw new Error(`${id}: manifest missing`);
  }

  const manifest =
    JSON.parse(
      fs.readFileSync(manifestPath,"utf8")
    );

  if (
    manifest.status !== "production" ||
    manifest.commercialReady !== true
  ) {
    throw new Error(
      `${id}: optimisation requires an approved production asset`
    );
  }

  const master =
    path.join(
      root,
      "assets",
      "masters",
      `${id}.png`
    );

  if (!fs.existsSync(master)) {
    throw new Error(
      `${id}: approved PNG master missing`
    );
  }

  const output =
    path.join(
      root,
      "packages",
      "assets",
      "src",
      "generated",
      `${id}.webp`
    );

  const before =
    await sharp(master)
      .metadata();

  await sharp(master)
    .rotate()
    .resize({
      width: MAX_EDGE,
      height: MAX_EDGE,
      fit: "inside",
      withoutEnlargement: true
    })
    .webp({
      quality: WEBP_QUALITY,
      effort: 5,
      smartSubsample: true
    })
    .toFile(output);

  const after =
    await sharp(output)
      .metadata();

  const runtimeBytes =
    fs.statSync(output)
      .size;

  if (runtimeBytes > TARGET_MAX_BYTES) {
    throw new Error(
      `${id}: runtime WebP is ${runtimeBytes} bytes; exceeds ${TARGET_MAX_BYTES}`
    );
  }

  manifest.runtime = {
    ...(manifest.runtime ?? {}),
    file:
      `packages/assets/src/generated/${id}.webp`
  };

  manifest.runtimeOptimisation = {
    sourceMaster:
      `assets/masters/${id}.png`,

    sourceSha256:
      sha256(master),

    runtimeSha256:
      sha256(output),

    masterDimensions: {
      width:
        before.width ?? null,

      height:
        before.height ?? null
    },

    runtimeDimensions: {
      width:
        after.width ?? null,

      height:
        after.height ?? null
    },

    runtimeFormat:
      "webp",

    quality:
      WEBP_QUALITY,

    maxEdge:
      MAX_EDGE,

    runtimeBytes
  };

  fs.writeFileSync(
    manifestPath,
    JSON.stringify(
      manifest,
      null,
      2
    ) + "\n",
    "utf8"
  );

  console.log(
    `${id}: PNG ${fs.statSync(master).size} -> WebP ${runtimeBytes} bytes (${after.width}x${after.height})`
  );
}

console.log(
  "RUNTIME IMAGE OPTIMISATION: PASS"
);
