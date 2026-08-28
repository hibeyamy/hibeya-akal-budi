import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import sharp from "sharp";

const root = process.cwd();
const reviewDir = path.join(root, "packages/assets/source/review/fruit");
const ids = ["apple-red", "apple-green", "banana-yellow"];

async function readJson(file) {
  // PowerShell 5.1 Set-Content -Encoding UTF8 writes a UTF-8 BOM.
  // Strip U+FEFF so review records created by the previous gate remain valid.
  const text = (await fs.readFile(file, "utf8")).replace(/^\uFEFF/, "");
  return JSON.parse(text);
}

for (const id of ids) {
  const pngPath = path.join(reviewDir, `${id}.png`);
  const recordPath = path.join(reviewDir, `${id}.review.json`);
  const record = await readJson(recordPath);

  if (record.id !== id) throw new Error(`${id}: review-record ID mismatch`);
  if (record.visualReviewed !== true) throw new Error(`${id}: human visual review is not recorded`);
  if (record.productionEnabled === true) throw new Error(`${id}: candidate is already production-enabled`);

  const metadata = await sharp(pngPath).metadata();
  if (metadata.format !== "png") throw new Error(`${id}: staged candidate must remain PNG`);
  if (!metadata.width || !metadata.height || metadata.width < 1024 || metadata.height < 1024) {
    throw new Error(`${id}: staged candidate must be at least 1024x1024; received ${metadata.width ?? "?"}x${metadata.height ?? "?"}`);
  }

  const stat = await fs.stat(pngPath);
  console.log(`PASS | ${id} | ${metadata.width}x${metadata.height} | ${stat.size} bytes | ${metadata.hasAlpha ? "alpha" : "opaque"}`);
}

console.log("FRUIT CANDIDATE TECHNICAL REVIEW: PASS");
