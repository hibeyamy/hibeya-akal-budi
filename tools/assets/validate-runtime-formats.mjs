import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const manifestRoot = path.join(root,"assets","manifests");
const allowed = new Set([".svg",".png",".webp",".jpg",".jpeg"]);
const failures = [];

for (const file of fs.readdirSync(manifestRoot).filter(f => f.endsWith(".json")).sort()) {
  const manifest = JSON.parse(fs.readFileSync(path.join(manifestRoot,file),"utf8"));
  if (manifest.commercialReady !== true) continue;

  const runtimeFile = manifest.runtime?.file;

  if (!runtimeFile) {
    failures.push(`${manifest.id}: approved asset missing runtime.file`);
    continue;
  }

  const absolute = path.join(root,runtimeFile);

  if (!fs.existsSync(absolute)) {
    failures.push(`${manifest.id}: runtime file missing (${runtimeFile})`);
    continue;
  }

  const ext = path.extname(runtimeFile).toLowerCase();

  if (!allowed.has(ext)) {
    failures.push(`${manifest.id}: unsupported runtime extension ${ext}`);
  }

  if (fs.statSync(absolute).size <= 0) {
    failures.push(`${manifest.id}: empty runtime file`);
  }

  if (ext === ".svg") {
    const svg = fs.readFileSync(absolute,"utf8");

    if (!svg.includes("<svg")) {
      failures.push(`${manifest.id}: invalid SVG root`);
    }

    if (/<script\b/i.test(svg) || /\bon[a-z]+\s*=/i.test(svg) || /<foreignObject\b/i.test(svg)) {
      failures.push(`${manifest.id}: unsafe SVG content`);
    }
  }
}

if (failures.length) {
  for (const failure of failures) console.error(`ASSET FORMAT ERROR: ${failure}`);
  process.exit(1);
}

console.log("ASSET FORMAT VALIDATION: PASS");
