import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import sharp from "sharp";

const root = process.cwd();
const check = process.argv.includes("--check");
const ids = ["hibiscus-red", "hibiscus-yellow", "hibiscus-purple"];
const sourceDir = path.join(root, "packages/assets/source/masters/flora");
const outputDir = path.join(root, "packages/assets/src/generated");

const policy = Object.freeze({
  width: 1024,
  height: 1024,
  quality: 82,
  effort: 6,
  targetBytes: 100 * 1024,
  hardMaxBytes: 160 * 1024
});

async function exists(file) {
  try { await fs.access(file); return true; } catch { return false; }
}

for (const id of ids) {
  const source = path.join(sourceDir, `${id}.png`);
  const output = path.join(outputDir, `${id}.webp`);
  if (!(await exists(source))) throw new Error(`Missing master: ${source}`);

  const master = await sharp(source).metadata();
  if (!master.width || !master.height ||
      master.width < policy.width || master.height < policy.height) {
    throw new Error(`${id}: master too small (${master.width ?? "?"}x${master.height ?? "?"})`);
  }

  const sourceHasAlpha = master.hasAlpha === true;

  const derivative = await sharp(source)
    .resize(policy.width, policy.height, { fit: "contain", withoutEnlargement: true })
    .webp({ quality: policy.quality, effort: policy.effort, alphaQuality: 100 })
    .toBuffer();

  if (derivative.length > policy.hardMaxBytes) {
    throw new Error(
      `${id}: ${derivative.length} bytes exceeds hard production limit ` +
      `${policy.hardMaxBytes} bytes`
    );
  }

  const runtime = await sharp(derivative).metadata();
  if (runtime.width !== policy.width || runtime.height !== policy.height) {
    throw new Error(`${id}: invalid derivative dimensions ${runtime.width}x${runtime.height}`);
  }
  if (sourceHasAlpha && !runtime.hasAlpha) {
    throw new Error(`${id}: source contains alpha but derivative lost transparency`);
  }

  const sizeState =
    derivative.length <= policy.targetBytes
      ? "within-target"
      : "above-target-within-hard-limit";
  const alphaState = sourceHasAlpha ? "alpha-preserved" : "opaque-source";

  if (check) {
    if (!(await exists(output))) throw new Error(`${id}: derivative missing`);
    const current = await fs.readFile(output);
    if (!current.equals(derivative)) throw new Error(`${id}: stale derivative; regenerate it`);
    console.log(`PASS ${id}: ${derivative.length} bytes, ${sizeState}, ${alphaState}`);
  } else {
    await fs.mkdir(outputDir, { recursive: true });
    await fs.writeFile(output, derivative);
    console.log(`GENERATED ${path.relative(root, output)} (${derivative.length} bytes, ${sizeState}, ${alphaState})`);
  }
}
console.log(check ? "RASTER PIPELINE CHECK: PASS" : "RASTER PIPELINE: PASS");
