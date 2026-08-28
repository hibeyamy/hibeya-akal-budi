import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import sharp from "sharp";

const root = process.cwd();
const check = process.argv.includes("--check");
const ids = ["hibiscus-red", "hibiscus-yellow", "hibiscus-purple"];
const sourceDir = path.join(root, "packages/assets/source/masters/flora");
const outputDir = path.join(root, "packages/assets/src/generated");
const policy = Object.freeze({ width: 1024, height: 1024, quality: 82, effort: 6, maxBytes: 102400 });

async function exists(file) {
  try { await fs.access(file); return true; } catch { return false; }
}

for (const id of ids) {
  const source = path.join(sourceDir, `${id}.png`);
  const output = path.join(outputDir, `${id}.webp`);
  if (!(await exists(source))) throw new Error(`Missing master: ${source}`);

  const master = await sharp(source).metadata();
  if (!master.width || !master.height || master.width < policy.width || master.height < policy.height)
    throw new Error(`${id}: master too small (${master.width}x${master.height})`);
  if (!master.hasAlpha) throw new Error(`${id}: master must preserve transparency`);

  const derivative = await sharp(source)
    .resize(policy.width, policy.height, { fit: "contain", withoutEnlargement: true })
    .webp({ quality: policy.quality, effort: policy.effort, alphaQuality: 100 })
    .toBuffer();

  if (derivative.length > policy.maxBytes)
    throw new Error(`${id}: ${derivative.length} bytes exceeds ${policy.maxBytes}`);

  const meta = await sharp(derivative).metadata();
  if (meta.width !== policy.width || meta.height !== policy.height)
    throw new Error(`${id}: invalid derivative dimensions ${meta.width}x${meta.height}`);
  if (!meta.hasAlpha) throw new Error(`${id}: derivative lost transparency`);

  if (check) {
    if (!(await exists(output))) throw new Error(`${id}: derivative missing`);
    const current = await fs.readFile(output);
    if (!current.equals(derivative)) throw new Error(`${id}: stale derivative; regenerate it`);
    console.log(`PASS ${id}: ${derivative.length} bytes`);
  } else {
    await fs.mkdir(outputDir, { recursive: true });
    await fs.writeFile(output, derivative);
    console.log(`GENERATED ${path.relative(root, output)} (${derivative.length} bytes)`);
  }
}
console.log(check ? "RASTER PIPELINE CHECK: PASS" : "RASTER PIPELINE: PASS");
