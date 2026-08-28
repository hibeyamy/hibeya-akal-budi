import fs from "node:fs/promises";
import fsSync from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const ids = ["apple-red", "apple-green", "banana-yellow"];
const registryPath = path.join(root, "packages/assets/src/generated/commercialRegistry.generated.ts");
const registry = await fs.readFile(registryPath, "utf8");

for (const id of ids) {
  const master = path.join(root, `packages/assets/source/masters/fruit/${id}.png`);
  const webp = path.join(root, `packages/assets/src/generated/${id}.webp`);
  const review = JSON.parse(
    (await fs.readFile(path.join(root, `packages/assets/source/review/fruit/${id}.review.json`), "utf8"))
      .replace(/^\uFEFF/, "")
  );

  if (!fsSync.existsSync(master)) throw new Error(`${id}: authoritative PNG master missing`);
  if (!fsSync.existsSync(webp)) throw new Error(`${id}: WebP derivative missing`);
  if (!registry.includes(`"./${id}.webp"`)) throw new Error(`${id}: registry does not expose WebP`);
  if (registry.includes(`"./${id}.svg"`)) throw new Error(`${id}: registry still exposes SVG`);
  if (review.productionEnabled !== true) throw new Error(`${id}: review audit not marked production-enabled`);

  console.log(`PASS: ${id} master + WebP + registry + audit`);
}

console.log("CONTROLLED FRUIT PROMOTION VERIFY: PASS");
