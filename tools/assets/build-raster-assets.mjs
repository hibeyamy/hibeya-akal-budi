import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import sharp from "sharp";

const root = process.cwd();
const check = process.argv.includes("--check");
const manifestPath = path.join(
  root,
  "packages/assets/source/raster-assets.json"
);

const manifest = JSON.parse(
  await fs.readFile(manifestPath, "utf8")
);

async function exists(file) {
  try {
    await fs.access(file);
    return true;
  } catch {
    return false;
  }
}

for (const entry of manifest.assets) {
  if (entry.state !== "production") {
    continue;
  }

  const source = path.join(root, entry.masterPath);
  const output = path.join(root, entry.deliveryPath);
  const policy = entry.policy;

  if (!(await exists(source))) {
    throw new Error(`${entry.id}: missing master ${entry.masterPath}`);
  }

  const master = await sharp(source).metadata();

  if (
    !master.width ||
    !master.height ||
    master.width < policy.width ||
    master.height < policy.height
  ) {
    throw new Error(
      `${entry.id}: master too small (${master.width ?? "?"}x${master.height ?? "?"})`
    );
  }

  const sourceHasAlpha = master.hasAlpha === true;

  const derivative = await sharp(source)
    .resize(policy.width, policy.height, {
      fit: "contain",
      withoutEnlargement: true
    })
    .webp({
      quality: policy.quality,
      effort: policy.effort,
      alphaQuality: 100
    })
    .toBuffer();

  if (derivative.length > policy.hardMaxBytes) {
    throw new Error(
      `${entry.id}: ${derivative.length} bytes exceeds hard limit ${policy.hardMaxBytes}`
    );
  }

  const runtime = await sharp(derivative).metadata();

  if (
    runtime.width !== policy.width ||
    runtime.height !== policy.height
  ) {
    throw new Error(
      `${entry.id}: derivative dimensions ${runtime.width}x${runtime.height}`
    );
  }

  if (sourceHasAlpha && !runtime.hasAlpha) {
    throw new Error(
      `${entry.id}: source contains alpha but derivative lost transparency`
    );
  }

  const sizeState =
    derivative.length <= policy.targetBytes
      ? "within-target"
      : "above-target-within-hard-limit";

  if (check) {
    if (!(await exists(output))) {
      throw new Error(`${entry.id}: derivative missing`);
    }

    const current = await fs.readFile(output);

    if (!current.equals(derivative)) {
      throw new Error(
        `${entry.id}: stale derivative; run build-raster-assets.mjs`
      );
    }

    console.log(
      `PASS ${entry.id}: ${derivative.length} bytes, ${sizeState}`
    );
  } else {
    await fs.mkdir(path.dirname(output), {
      recursive: true
    });

    await fs.writeFile(output, derivative);

    console.log(
      `GENERATED ${entry.deliveryPath} (${derivative.length} bytes, ${sizeState})`
    );
  }
}

console.log(
  check
    ? "RASTER PIPELINE CHECK: PASS"
    : "RASTER PIPELINE: PASS"
);
