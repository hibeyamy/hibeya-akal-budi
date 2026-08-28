import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";
import process from "node:process";

const root = process.cwd();
const migrationPath = path.join(root, "packages/assets/source/asset-migration.json");
const rasterPath = path.join(root, "packages/assets/source/raster-assets.json");

const readJson = async file =>
  JSON.parse((await fs.readFile(file, "utf8")).replace(/^\uFEFF/, ""));

const sha = async file =>
  crypto.createHash("sha256").update(await fs.readFile(file)).digest("hex").toUpperCase();

const migration = await readJson(migrationPath);
const raster = await readJson(rasterPath);

migration.policy.runtimeDelivery = "webp";
migration.policy.legacyPrototype = "svg";
migration.policy.semanticIdsStable = true;
migration.policy.fruitSvgMigrationDeferred = false;
migration.policy.sourceMaster = "png";
migration.closedOutAt = new Date().toISOString();

const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow",
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

migration.assets = [];

for (const id of ids) {
  const entry = raster.assets.find(item => item.id === id);
  if (!entry || entry.state !== "production") {
    throw new Error(`${id}: production raster contract missing`);
  }

  const master = path.join(root, entry.masterPath);
  const runtime = path.join(root, entry.deliveryPath);
  const category = entry.category === "fruit" ? "fruit" : "flora";
  const legacyRel = `packages/assets/source/legacy/${category}/${id}.svg`;
  const legacy = path.join(root, legacyRel);

  migration.assets.push({
    id,
    master: entry.masterPath.replace("packages/assets/", ""),
    runtime: entry.deliveryPath.replace("packages/assets/", ""),
    legacy: legacyRel.replace("packages/assets/", ""),
    masterSha256: await sha(master),
    legacySha256: await sha(legacy),
    runtimeSha256: await sha(runtime)
  });
}

await fs.writeFile(
  migrationPath,
  JSON.stringify(migration, null, 2) + "\\n",
  "utf8"
);

const parent = path.join(root, "apps/parent-web/src/App.tsx");
let text = await fs.readFile(parent, "utf8");
text = text
  .replaceAll("â€”", "—")
  .replaceAll("â€“", "–");
await fs.writeFile(parent, text, "utf8");

console.log("ASSET GOVERNANCE CLOSE-OUT DATA: PASS");
