import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const governed = [
  "apple-red",
  "apple-green",
  "banana-yellow",
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

const fail = message => { throw new Error(message); };
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");
const exists = relative => fs.existsSync(path.join(root, relative));

const registryPath = "packages/assets/src/generated/commercialRegistry.generated.ts";
const rasterPath = "packages/assets/source/raster-assets.json";
const assetIndexPath = "packages/assets/src/index.ts";

const registry = read(registryPath);
const raster = JSON.parse(read(rasterPath));
const assetIndex = read(assetIndexPath);

if (!assetIndex.includes("commercialAssetOverrides[assetId] ??")) {
  fail("getAsset() no longer gives commercial governed assets precedence.");
}
if (!assetIndex.includes("throw new Error(`Unknown asset: ${assetId}`)")) {
  fail("Unknown semantic assets no longer fail explicitly.");
}

for (const id of governed) {
  const entry = raster.assets.find(asset => asset.id === id);
  if (!entry) fail(`${id}: missing raster manifest entry`);
  if (entry.state !== "production") fail(`${id}: raster state is not production`);
  if (!entry.deliveryPath.endsWith(`/${id}.webp`)) {
    fail(`${id}: delivery path is not governed WebP`);
  }
  if (!exists(entry.deliveryPath)) fail(`${id}: governed WebP derivative missing`);
  if (!registry.includes(`"${id}": {`)) fail(`${id}: missing commercial registry entry`);
  if (!registry.includes(`"./${id}.webp"`)) fail(`${id}: commercial registry does not resolve WebP`);
}

const runtimeRoots = [
  "apps/learner-web/src",
  "packages/content-library/src"
];

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(full);
    return /\.(ts|tsx|js|mjs|json)$/.test(entry.name) ? [full] : [];
  });
}

const runtimeFiles = runtimeRoots.flatMap(relative => walk(path.join(root, relative)));
const forbidden = [
  /source[\\/](review|masters|legacy)/i,
  /packages[\\/]assets[\\/]src[\\/]generated/i,
  /storybook-static/i
];

for (const file of runtimeFiles) {
  const source = fs.readFileSync(file, "utf8");
  const relative = path.relative(root, file);
  for (const pattern of forbidden) {
    if (pattern.test(source)) fail(`${relative}: runtime leak matched ${pattern}`);
  }

  // Content and learner code may name semantic IDs, but must not directly name
  // the governed delivery files.
  for (const id of governed) {
    if (
      source.includes(`${id}.webp`) ||
      source.includes(`${id}.png`) ||
      source.includes(`${id}.svg`)
    ) {
      fail(`${relative}: hard-coded physical path for ${id}`);
    }
  }
}

const player = read("apps/learner-web/src/features/play/ActivityPlayer.tsx");
if (!/getAsset\s*\(\s*option\.asset\s*\)/m.test(player)) {
  fail("ActivityPlayer no longer resolves option.asset through getAsset().");
}
if (!/mechanic\.submitAnswer\s*\(/m.test(player)) {
  fail("ActivityPlayer no longer delegates correctness to the mechanic.");
}

const catalogue = read("packages/content-library/src/catalogue.ts");
if (!catalogue.includes('implementationKey:')) {
  fail("Playable catalogue lost implementationKey contract.");
}

console.log("PASS: six governed semantic assets are production WebP-backed");
console.log("PASS: commercial overrides precede legacy fallback representations");
console.log("PASS: unknown asset IDs fail explicitly");
console.log("PASS: learner/content runtime contains no governed physical-path leaks");
console.log("PASS: ActivityPlayer resolves semantic option.asset through getAsset()");
console.log("PASS: correctness remains delegated to mechanic.submitAnswer()");
