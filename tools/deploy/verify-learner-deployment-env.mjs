import fs from "node:fs";
import path from "node:path";

const platform=process.argv.includes("--platform");
const repo=process.cwd();

function parseEnvFile(file){
  if(!fs.existsSync(file)) return {};
  const out={};
  for(const raw of fs.readFileSync(file,"utf8").split(/\r?\n/)){
    const line=raw.trim();
    if(!line || line.startsWith("#")) continue;
    const i=line.indexOf("=");
    if(i<1) continue;
    out[line.slice(0,i).trim()]=line.slice(i+1).trim();
  }
  return out;
}

const production=parseEnvFile(path.join(repo,"apps","learner-web",".env.production"));
const example=parseEnvFile(path.join(repo,"apps","learner-web",".env.example"));

function value(name){
  if(process.env[name]!==undefined) return process.env[name];
  if(platform) return undefined;
  if(production[name]!==undefined) return production[name];
  return example[name];
}

const url=value("VITE_SUPABASE_URL");
const key=value("VITE_SUPABASE_PUBLISHABLE_KEY");
const enabled=value("VITE_HIBEYA_ADAPTIVE_ENABLED");
const rollout=value("VITE_HIBEYA_ADAPTIVE_ROLLOUT_PERCENT");

let parsedUrl;
try{
  parsedUrl=new URL(url);
}catch{
  throw new Error("VITE_SUPABASE_URL missing or invalid.");
}
if(parsedUrl.protocol!=="https:" || !parsedUrl.hostname.endsWith(".supabase.co")){
  throw new Error("VITE_SUPABASE_URL must be an https://*.supabase.co URL.");
}

if(!key || !(key.startsWith("sb_publishable_") || key.startsWith("eyJ"))){
  throw new Error("VITE_SUPABASE_PUBLISHABLE_KEY missing or invalid.");
}

const off=enabled==="false" && rollout==="0";
const one=enabled==="true" && rollout==="1";
if(!off && !one){
  throw new Error("Adaptive deployment must be exactly false/0 (kill switch) or true/1 (controlled cohort).");
}

console.log("PASS: learner deployment environment is valid.");
console.log("AdaptiveState="+(one?"CONTROLLED_1_PERCENT":"KILL_SWITCH_0_PERCENT"));
