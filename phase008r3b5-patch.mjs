import fs from "node:fs/promises";
import path from "node:path";

const file=path.join(process.cwd(),"apps/learner-web/src/features/play/ActivityPlayer.tsx");
let s=await fs.readFile(file,"utf8");
const before='"transition duration-150 active:scale-[0.98]",';
const after='"transition duration-150 active:scale-[0.98] motion-reduce:transition-none motion-reduce:active:scale-100",';
const count=s.split(before).length-1;
if(count!==1) throw new Error(`Expected one learner-choice motion boundary, found ${count}`);
s=s.replace(before,after);
await fs.writeFile(file,s,"utf8");
console.log("PATCHED: learner choice respects reduced-motion preference");
