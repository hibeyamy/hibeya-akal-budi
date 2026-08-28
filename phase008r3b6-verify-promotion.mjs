import fs from "node:fs";
import path from "node:path";
const root=process.cwd();
const hits=[];
function walk(dir){
 if(!fs.existsSync(dir))return;
 for(const e of fs.readdirSync(dir,{withFileTypes:true})){
  if(["node_modules","dist","storybook-static","tools"].includes(e.name))continue;
  const p=path.join(dir,e.name);
  if(e.isDirectory())walk(p);
  else if(e.name.endsWith(".json")&&fs.readFileSync(p,"utf8").includes("beza-bunga-raya-001"))hits.push(p);
 }
}
walk(root);
if(hits.length!==1)throw new Error(`Manifest count ${hits.length}`);
const text=fs.readFileSync(hits[0],"utf8"),doc=JSON.parse(text);
function find(n){if(!n||typeof n!=="object")return null;if(n.id==="beza-bunga-raya-001")return n;for(const v of Object.values(n)){const r=find(v);if(r)return r}return null}
const a=find(doc);if(!a)throw new Error("Activity absent");
function value(n,k){if(!n||typeof n!=="object")return undefined;if(Object.prototype.hasOwnProperty.call(n,k))return n[k];for(const v of Object.values(n)){const r=value(v,k);if(r!==undefined)return r}}
for(const [k,v] of [["originalityReviewed",true],["culturalReviewed",true],["reviewedBy","HilmiBeya"],["active",true],["enabled",true]]){
 if(value(a,k)!==v)throw new Error(`${k} not promoted`);
}
const at=value(a,"reviewedAt");if(!at||Number.isNaN(Date.parse(at)))throw new Error("reviewedAt invalid");
console.log("PASS: human approval metadata recorded");
console.log("PASS: activity active and catalogue enabled");
