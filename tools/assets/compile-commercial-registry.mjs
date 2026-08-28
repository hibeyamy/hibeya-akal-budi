import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const manifestRoot = path.join(root,"assets","manifests");
const output = path.join(root,"packages","assets","src","generated","commercialRegistry.generated.ts");

const approved = [];

for (const file of fs.readdirSync(manifestRoot).filter(f => f.endsWith(".json")).sort()) {
  const manifest = JSON.parse(fs.readFileSync(path.join(manifestRoot,file),"utf8"));

  if (manifest.commercialReady !== true) continue;

  const id = manifest.id;
  const runtimeFile = manifest.runtime?.file;
  const alt = manifest.runtime?.alt;

  if (!runtimeFile || !alt?.ms || !alt?.en) {
    console.error(`${id}: commercial asset is missing runtime metadata`);
    process.exit(1);
  }

  const expectedPrefix = "packages/assets/src/generated/";

  if (!runtimeFile.startsWith(expectedPrefix)) {
    console.error(`${id}: runtime file must be inside ${expectedPrefix}`);
    process.exit(1);
  }

  const absolute = path.join(root,runtimeFile);

  if (!fs.existsSync(absolute)) {
    console.error(`${id}: runtime asset file does not exist`);
    process.exit(1);
  }

  approved.push({
    id,
    fileName: path.basename(runtimeFile),
    alt
  });
}

const lines = [
  "// GENERATED FILE. DO NOT EDIT.",
  "// Source: assets/manifests/*.json where commercialReady=true",
  "",
  "export const generatedCommercialAssetOverrides = {"
];

for (const asset of approved) {
  lines.push(`  ${JSON.stringify(asset.id)}: {`);
  lines.push(`    id: ${JSON.stringify(asset.id)},`);
  lines.push('    type: "image" as const,');
  lines.push("    value: new URL(");
  lines.push(`      ${JSON.stringify(`./${asset.fileName}`)},`);
  lines.push("      import.meta.url");
  lines.push("    ).href,");
  lines.push("    alt: {");
  lines.push(`      ms: ${JSON.stringify(asset.alt.ms)},`);
  lines.push(`      en: ${JSON.stringify(asset.alt.en)}`);
  lines.push("    }");
  lines.push("  },");
}

lines.push("} as const;");
lines.push("");
lines.push("export type GeneratedCommercialAssetId =");
lines.push('  keyof typeof generatedCommercialAssetOverrides;');
lines.push("");

const body = lines.join("\n") + "\n";
const check = process.argv.includes("--check");

if (check) {
  if (!fs.existsSync(output) || fs.readFileSync(output,"utf8") !== body) {
    console.error("COMMERCIAL REGISTRY CHECK: generated output is out of date");
    process.exit(1);
  }

  console.log(`COMMERCIAL REGISTRY CHECK: PASS (${approved.length} approved assets)`);
  process.exit(0);
}

fs.mkdirSync(path.dirname(output),{recursive:true});
fs.writeFileSync(output,body,"utf8");
console.log(`COMMERCIAL REGISTRY: ${approved.length} approved assets compiled`);
