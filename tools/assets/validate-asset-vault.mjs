import crypto from "node:crypto";import fs from "node:fs";import path from "node:path";import process from "node:process";
const root=process.cwd(),p=path.join(root,"assets","vault","catalogue.json"),bad=[];if(!fs.existsSync(p)){console.error("ASSET VAULT ERROR: catalogue missing");process.exit(1)}
const c=JSON.parse(fs.readFileSync(p,"utf8")),h=f=>crypto.createHash("sha256").update(fs.readFileSync(f)).digest("hex"),ids=new Set();
for(const a of c.assets??[]){if(ids.has(a.id))bad.push(`${a.id}: duplicate`);ids.add(a.id);if(!Number.isInteger(a.version)||a.version<1)bad.push(`${a.id}: invalid version`);
 const r=path.join(root,a.runtimeFile);if(!fs.existsSync(r))bad.push(`${a.id}: runtime missing`);else if(h(r)!==a.runtimeSha256)bad.push(`${a.id}: runtime hash mismatch`);
 if(a.masterFile){const m=path.join(root,a.masterFile);if(!fs.existsSync(m))bad.push(`${a.id}: master missing`);else if(h(m)!==a.masterSha256)bad.push(`${a.id}: master hash mismatch`)}}
if(c.assetCount!==(c.assets??[]).length)bad.push("assetCount mismatch");if(bad.length){bad.forEach(x=>console.error(`ASSET VAULT ERROR: ${x}`));process.exit(1)}
console.log(`ASSET VAULT VALIDATION: PASS (${c.assetCount} assets)`);
