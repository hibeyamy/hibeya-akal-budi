import fs from "node:fs/promises";
import path from "node:path";

const file = path.join(process.cwd(), "apps/learner-web/src/features/play/ActivityPlayer.tsx");
let s = await fs.readFile(file, "utf8");

const bad = `        data-session-mode={localSession ? "local" : "remote"}\n`;
const count = s.split(bad).length - 1;
if (count !== 1) {
  throw new Error(`Expected exactly one invalid data-session-mode hook, found ${count}. Repository was not modified.`);
}

s = s.replace(bad, "");
await fs.writeFile(file, s, "utf8");
console.log("PATCHED: removed invalid localSession observability hook");
