import crypto from "node:crypto"; import fs from "node:fs"; import path from "node:path"; import process from "node:process";
const root=process.cwd(), md=path.join(root,"assets","manifests"), vd=path.join(root,"assets","vault"), cp=path.join(vd,"catalogue.json");
fs.mkdirSync(vd,{recursive:true});
const hash=f=>crypto.createHash("sha256").update(fs.readFileSync(f)).digest("hex");
const old=fs.existsSync(cp)?JSON.parse(fs.readFileSync(cp,"utf8")):{assets:[]};
const assets=[];
for(const n of fs.readdirSync(md).filter(x=>x.endsWith(".json")).sort()){
 const m=JSON.parse(fs.readFileSync(path.join(md,n),"utf8")); if(m.status!=="production"||m.commercialReady!==true)continue;
 const rr=m.runtime?.file;if(!rr)throw new Error(`${m.id}: missing runtime.file`);const ra=path.join(root,rr);if(!fs.existsSync(ra))throw new Error(`${m.id}: runtime missing`);
 const mr=m.sourceFile??m.runtimeOptimisation?.sourceMaster??null, ma=mr?path.join(root,mr):null, rh=hash(ra), mh=ma&&fs.existsSync(ma)?hash(ma):null;
 const prev=old.assets?.find(x=>x.id===m.id);let version=prev?.version??1;if(prev&&(prev.runtimeSha256!==rh||prev.masterSha256!==mh))version++;
 assets.push({id:m.id,version,status:"production",commercialReady:true,masterFile:mr,masterSha256:mh,runtimeFile:rr,runtimeSha256:rh,runtimeBytes:fs.statSync(ra).size,alt:m.runtime?.alt??null});
}
fs.writeFileSync(cp,JSON.stringify({schemaVersion:1,assetCount:assets.length,assets},null,2)+"\n");
console.log(`ASSET VAULT: ${assets.length} production assets catalogued`);
