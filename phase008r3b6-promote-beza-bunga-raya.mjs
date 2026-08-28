import fs from "node:fs";
import path from "node:path";

const root=process.cwd();
const candidates=[];
function walk(dir){
  if(!fs.existsSync(dir)) return;
  for(const e of fs.readdirSync(dir,{withFileTypes:true})){
    if(["node_modules","dist","storybook-static","tools"].includes(e.name)) continue;
    const p=path.join(dir,e.name);
    if(e.isDirectory()) walk(p);
    else if(e.name.endsWith(".json")){
      const s=fs.readFileSync(p,"utf8");
      if(s.includes("beza-bunga-raya-001")) candidates.push(p);
    }
  }
}
walk(root);
if(candidates.length!==1) throw new Error(`Expected exactly one activity manifest, found ${candidates.length}: ${candidates.join(", ")}`);
const file=candidates[0];
const doc=JSON.parse(fs.readFileSync(file,"utf8"));

function findObjectWithId(node){
  if(!node||typeof node!=="object") return null;
  if(node.id==="beza-bunga-raya-001") return node;
  for(const v of Object.values(node)){
    const r=findObjectWithId(v); if(r) return r;
  }
  return null;
}
const a=findObjectWithId(doc);
if(!a) throw new Error("Activity object not found");

// Guard the exact reviewed content contract before changing release metadata.
const raw=JSON.stringify(a);
for(const id of ["hibiscus-red","hibiscus-yellow"]){
  if(!raw.includes(id)) throw new Error(`Reviewed semantic asset missing: ${id}`);
}
if(!raw.includes("visual-discrimination")) throw new Error("Reviewed primary competency missing");

// Locate existing governance fields rather than inventing a parallel schema.
function setExisting(node,key,value){
  if(!node||typeof node!=="object") return false;
  if(Object.prototype.hasOwnProperty.call(node,key)){ node[key]=value; return true; }
  for(const v of Object.values(node)){ if(setExisting(v,key,value)) return true; }
  return false;
}
const reviewedAt=new Date().toISOString();
const required=[
  ["originalityReviewed",true],
  ["culturalReviewed",true],
  ["reviewedBy","HilmiBeya"],
  ["reviewedAt",reviewedAt],
  ["active",true],
  ["enabled",true]
];
for(const [k,v] of required){
  if(!setExisting(a,k,v)) throw new Error(`Existing governance field not found: ${k}`);
}

fs.writeFileSync(file,JSON.stringify(doc,null,2)+"\n","utf8");
console.log(`PROMOTED: ${path.relative(root,file)}`);
console.log(`REVIEWER: HilmiBeya`);
console.log(`REVIEWED_AT: ${reviewedAt}`);
console.log("APPROVAL BASIS: explicit human approval of visual, originality, cultural suitability and age suitability");
