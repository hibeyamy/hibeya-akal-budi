import fs from "node:fs/promises";
import fsSync from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import process from "node:process";

const root = process.cwd();
const ids = ["apple-red", "apple-green", "banana-yellow"];
const rasterManifestPath = path.join(root, "packages/assets/source/raster-assets.json");
const replacementPlanPath = path.join(root, "packages/assets/source/visual-replacement-plan.json");
const reviewDir = path.join(root, "packages/assets/source/review/fruit");
const masterDir = path.join(root, "packages/assets/source/masters/fruit");
const generatedDir = path.join(root, "packages/assets/src/generated");
const commercialManifestDir = path.join(root, "assets/manifests");

const policy = {
  width: 1024,
  height: 1024,
  quality: 82,
  effort: 6,
  targetBytes: 102400,
  hardMaxBytes: 163840
};

const readJson = async file =>
  JSON.parse((await fs.readFile(file, "utf8")).replace(/^\uFEFF/, ""));

const writeJson = async (file, value) => {
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, JSON.stringify(value, null, 2) + "\n", "utf8");
};

const sha256 = buffer =>
  crypto.createHash("sha256").update(buffer).digest("hex").toUpperCase();

const raster = await readJson(rasterManifestPath);
const plan = await readJson(replacementPlanPath);

for (const id of ids) {
  const reviewPng = path.join(reviewDir, `${id}.png`);
  const reviewJson = path.join(reviewDir, `${id}.review.json`);
  const review = await readJson(reviewJson);

  if (review.id !== id || review.visualReviewed !== true || review.productionEnabled === true) {
    throw new Error(`${id}: reviewed candidate state is not eligible for promotion`);
  }

  const candidate = await fs.readFile(reviewPng);
  const masterPath = path.join(masterDir, `${id}.png`);

  await fs.mkdir(masterDir, { recursive: true });
  await fs.writeFile(masterPath, candidate);

  const copied = await fs.readFile(masterPath);
  if (sha256(candidate) !== sha256(copied)) {
    throw new Error(`${id}: authoritative master copy hash mismatch`);
  }

  const entry = {
    id,
    state: "production",
    category: "fruit",
    masterPath: `packages/assets/source/masters/fruit/${id}.png`,
    deliveryPath: `packages/assets/src/generated/${id}.webp`,
    policy: { ...policy }
  };

  const index = raster.assets.findIndex(item => item.id === id);
  if (index >= 0) raster.assets[index] = entry;
  else raster.assets.push(entry);

  const planned = plan.assets.find(item => item.id === id);
  if (!planned) throw new Error(`${id}: visual replacement plan entry missing`);
  planned.state = "promoted-to-authoritative-master";
  planned.masterPath = entry.masterPath;
  planned.deliveryPath = entry.deliveryPath;

  const manifestPath = path.join(commercialManifestDir, `${id}.json`);
  if (!fsSync.existsSync(manifestPath)) {
    throw new Error(`${id}: commercial manifest missing at assets/manifests/${id}.json`);
  }
  const manifest = await readJson(manifestPath);
  if (manifest.id !== id) throw new Error(`${id}: commercial manifest ID mismatch`);
  if (manifest.commercialReady !== true) {
    throw new Error(`${id}: commercialReady is not true in existing manifest`);
  }
  manifest.runtime ??= {};
  manifest.runtime.file = entry.deliveryPath;
  await writeJson(manifestPath, manifest);

  review.productionEnabled = true;
  review.state = "promoted-to-production";
  review.promotedAt = new Date().toISOString();
  review.masterPath = entry.masterPath;
  review.deliveryPath = entry.deliveryPath;
  review.promotedSourceSha256 = sha256(candidate);
  await writeJson(reviewJson, review);

  console.log(`PROMOTED CONTRACT: ${id}`);
}

raster.assets.sort((a, b) => a.id.localeCompare(b.id));
await writeJson(rasterManifestPath, raster);
await writeJson(replacementPlanPath, plan);

console.log("FRUIT PROMOTION CONTRACT UPDATE: PASS");
