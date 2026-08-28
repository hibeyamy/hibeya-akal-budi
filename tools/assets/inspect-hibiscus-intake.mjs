import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const inbox = path.join(root,"assets","inbox","hibiscus");
const specPath = path.join(inbox,"batch.json");

const spec = JSON.parse(fs.readFileSync(specPath,"utf8"));
const allowed = new Set(spec.allowedExtensions.map(x => `.${x}`));
const failures = [];
const found = [];

for (const asset of spec.assets) {
  const matches = fs.readdirSync(inbox)
    .filter(file => path.parse(file).name === asset.id)
    .filter(file => allowed.has(path.extname(file).toLowerCase()));

  if (matches.length === 0) {
    if (asset.required) failures.push(`${asset.id}: artwork file is missing`);
    continue;
  }

  if (matches.length > 1) {
    failures.push(`${asset.id}: multiple candidate files found (${matches.join(", ")})`);
    continue;
  }

  const file = matches[0];
  const absolute = path.join(inbox,file);
  const stat = fs.statSync(absolute);

  if (stat.size <= 0) failures.push(`${asset.id}: file is empty`);

  found.push({
    id: asset.id,
    file,
    extension: path.extname(file).slice(1).toLowerCase(),
    bytes: stat.size
  });
}

if (failures.length) {
  console.error("HIBISCUS INTAKE: NOT READY");

  for (const failure of failures) {
    console.error(`- ${failure}`);
  }

  console.error("");
  console.error("Place exactly one approved candidate file for each asset in:");
  console.error("  assets/inbox/hibiscus/");
  console.error("");
  console.error("Accepted names:");
  for (const asset of spec.assets) {
    console.error(`  ${asset.id}.png OR .webp OR .svg`);
  }

  process.exit(2);
}

console.log("HIBISCUS INTAKE: READY");
for (const asset of found) {
  console.log(`- ${asset.id}: ${asset.file} (${asset.bytes} bytes)`);
}
