import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const dir = path.join(root,"assets","families");
const families = fs.readdirSync(dir).filter(f => f.endsWith(".json")).sort();

for (const file of families) {
  const f = JSON.parse(fs.readFileSync(path.join(dir,file),"utf8"));
  console.log(`${f.id}@${f.version}`);
  for (const m of f.members) {
    const manifest = JSON.parse(
      fs.readFileSync(path.join(root,"assets","manifests",`${m.id}.json`),"utf8")
    );
    console.log(`  ${m.id.padEnd(22)} ${manifest.status.padEnd(12)} commercial=${manifest.commercialReady === true ? "yes" : "no"}`);
  }
}
