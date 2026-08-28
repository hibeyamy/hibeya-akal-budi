import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow",
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

const failures = [];
const report = [];

for (const id of ids) {
  const files = [
    path.join(root,"assets","masters",`${id}.svg`),
    path.join(root,"assets","exports",`${id}.svg`),
    path.join(root,"packages","assets","src","generated",`${id}.svg`)
  ];

  for (const file of files) {
    if (!fs.existsSync(file)) failures.push(`${id}: missing ${path.relative(root,file)}`);
  }

  if (files.every(fs.existsSync)) {
    const hashes = files.map(file =>
      crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex")
    );
    if (new Set(hashes).size !== 1) failures.push(`${id}: master/export/runtime mismatch`);

    const svg = fs.readFileSync(files[0],"utf8");
    if (/<script\b|<foreignObject\b|\bon[a-z]+\s*=/i.test(svg)) failures.push(`${id}: unsafe SVG`);
    if (!/viewBox=/i.test(svg)) failures.push(`${id}: missing viewBox`);
  }

  report.push({
    id,
    humanVisualReviewRequired: true,
    target: "PRODUCTION_VISUAL_TARGET.md"
  });
}

fs.writeFileSync(
  path.join(root,"assets","visual-audit.json"),
  JSON.stringify({schemaVersion:1,assets:report},null,2)+"\n",
  "utf8"
);

if (failures.length) {
  failures.forEach(x => console.error(`VISUAL BASELINE ERROR: ${x}`));
  process.exit(1);
}

console.log("VISUAL BASELINE: PASS (6 assets structurally ready for human audit)");
