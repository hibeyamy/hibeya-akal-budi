import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const ids = [
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

let masterTotal = 0;
let runtimeTotal = 0;

console.log("");
console.log("HIBISCUS IMAGE BUDGET");
console.log("=====================");

for (const id of ids) {
  const master =
    path.join(root,"assets","masters",`${id}.png`);

  const runtime =
    path.join(root,"packages","assets","src","generated",`${id}.webp`);

  const masterBytes =
    fs.statSync(master).size;

  const runtimeBytes =
    fs.statSync(runtime).size;

  masterTotal += masterBytes;
  runtimeTotal += runtimeBytes;

  const saving =
    100 -
    (
      runtimeBytes /
      masterBytes *
      100
    );

  console.log(
    `${id.padEnd(20)} master=${(masterBytes/1024).toFixed(0).padStart(5)}KB  runtime=${(runtimeBytes/1024).toFixed(0).padStart(4)}KB  saving=${saving.toFixed(1)}%`
  );
}

console.log("---------------------");
console.log(
  `TOTAL master=${(masterTotal/1024/1024).toFixed(2)}MB runtime=${(runtimeTotal/1024/1024).toFixed(2)}MB`
);

console.log(
  `TOTAL saving=${(100-runtimeTotal/masterTotal*100).toFixed(1)}%`
);
