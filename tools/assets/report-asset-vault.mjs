import fs from "node:fs";import path from "node:path";import process from "node:process";
const c=JSON.parse(fs.readFileSync(path.join(process.cwd(),"assets","vault","catalogue.json"),"utf8"));
console.log("\nHIBEYA ASSET VAULT\n==================");for(const a of c.assets)console.log(`${a.id} | v${a.version} | ${(a.runtimeBytes/1024).toFixed(1)} KB | ${a.runtimeFile}`);console.log(`\nProduction assets: ${c.assetCount}`);
