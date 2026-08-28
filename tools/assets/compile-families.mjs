import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const familyDir = path.join(root,"assets","families");
const outFile = path.join(root,"packages","assets","src","generated","familyCatalogue.ts");

function hash(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

const families = fs.readdirSync(familyDir)
  .filter(f => f.endsWith(".json"))
  .sort()
  .map(file => JSON.parse(fs.readFileSync(path.join(familyDir,file),"utf8")));

const compiled = families.map(family => ({
  id: family.id,
  version: family.version,
  title: family.title,
  members: family.members.map(member => ({
    id: member.id,
    sha256: hash(path.join(root,member.master))
  }))
}));

const banner = `// GENERATED FILE. DO NOT EDIT.
// Source: assets/families/*.json

`;

const body =
  banner +
  `export const assetFamilyCatalogue = ${JSON.stringify(compiled,null,2)} as const;\n\n` +
  `export type AssetFamilyId = typeof assetFamilyCatalogue[number]["id"];\n`;

const check = process.argv.includes("--check");

if (check) {
  if (!fs.existsSync(outFile) || fs.readFileSync(outFile,"utf8") !== body) {
    console.error("ASSET FAMILY COMPILER CHECK: generated catalogue is out of date");
    process.exit(1);
  }
  console.log("ASSET FAMILY COMPILER CHECK: PASS");
} else {
  fs.mkdirSync(path.dirname(outFile),{recursive:true});
  fs.writeFileSync(outFile,body,"utf8");
  console.log(`ASSET FAMILY COMPILER: ${compiled.length} families compiled`);
}
