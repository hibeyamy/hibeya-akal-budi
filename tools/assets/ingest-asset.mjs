import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const [, , id, source, runtimeFormat] = process.argv;

if (!id || !source || !runtimeFormat) {
  console.error("Usage: pnpm assets:ingest <asset-id> <source-file> <svg|png|webp|jpg>");
  process.exit(1);
}

if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(id)) {
  console.error("Asset id must use kebab-case.");
  process.exit(1);
}

const allowed = new Set(["svg","png","webp","jpg"]);

if (!allowed.has(runtimeFormat)) {
  console.error(`Unsupported runtime format: ${runtimeFormat}`);
  process.exit(1);
}

const sourcePath = path.resolve(root,source);

if (!fs.existsSync(sourcePath)) {
  console.error(`Source file does not exist: ${source}`);
  process.exit(1);
}

const runtimeFile = path.join(
  root,
  "packages",
  "assets",
  "src",
  "generated",
  `${id}.${runtimeFormat}`
);

fs.mkdirSync(path.dirname(runtimeFile),{recursive:true});
fs.copyFileSync(sourcePath,runtimeFile);

const manifestPath = path.join(root,"assets","manifests",`${id}.json`);

if (fs.existsSync(manifestPath)) {
  const manifest = JSON.parse(fs.readFileSync(manifestPath,"utf8"));
  manifest.runtime ??= {};
  manifest.runtime.file = `packages/assets/src/generated/${id}.${runtimeFormat}`;
  manifest.status = "review";
  manifest.commercialReady = false;
  manifest.replacementRequiredForCommercialRelease = true;
  manifest.notes =
    "Asset ingested into runtime review state. Human visual/originality/rights/child-safety review is required before commercial approval.";

  fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2)+"\n","utf8");
}

console.log(`ASSET INGEST: ${id} -> ${path.relative(root,runtimeFile)}`);
console.log("STATUS: review; no commercial approval was granted automatically");
