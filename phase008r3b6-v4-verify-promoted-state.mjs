import fs from "node:fs";import path from "node:path";
const f=path.join(process.cwd(),"content","activity-manifests","beza-bunga-raya-001.json");
const d=JSON.parse(fs.readFileSync(f,"utf8")),a=d.activity,c=d.catalogue;
const checks=[["originalityReviewed",a?.provenance?.originalityReviewed===true],["culturalReviewed",a?.provenance?.culturalReviewed===true],["reviewedBy",a?.provenance?.reviewedBy==="HilmiBeya"],["reviewedAt",!Number.isNaN(Date.parse(a?.provenance?.reviewedAt??""))],["metadata.active",a?.metadata?.active===true],["catalogue.enabled",c?.enabled===true]];
for(const [n,ok] of checks){if(!ok)throw new Error(`${n}: promoted state not preserved`);console.log(`PASS: ${n}`)}
const x=(a.options??[]).filter(o=>o.correct===true);if(x.length!==1||x[0].asset!=="hibiscus-yellow")throw new Error("answer contract changed");
console.log("PASS: answer contract preserved");console.log("PASS: continuation-only; promotion metadata unchanged");
