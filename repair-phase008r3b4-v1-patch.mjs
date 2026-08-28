import fs from "node:fs/promises";
import path from "node:path";

const root = process.cwd();
const storyDir = path.join(root, "apps", "ui-storybook", "stories");
const learnerCss = path.join(root, "apps", "learner-web", "src", "index.css");

async function walk(dir) {
  const out = [];
  for (const e of await fs.readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...await walk(p));
    else if (/\.stories\.(ts|tsx)$/.test(e.name)) out.push(p);
  }
  return out;
}

await fs.access(learnerCss);
const stories = await walk(storyDir);
let target = null;

for (const file of stories) {
  const text = await fs.readFile(file, "utf8");
  if (
    text.includes('title: "Learner/Journey"') ||
    text.includes("title: 'Learner/Journey'") ||
    text.includes("LearnerJourney")
  ) {
    target = file;
    break;
  }
}
if (!target) throw new Error("Could not locate Learner/Journey Storybook source.");

let source = await fs.readFile(target, "utf8");
const relative = path.relative(path.dirname(target), learnerCss).replaceAll("\\", "/");
const specifier = relative.startsWith(".") ? relative : "./" + relative;
const importLine = `import "${specifier}";`;

if (!source.includes(importLine)) {
  const imports = [...source.matchAll(/^import .*;$/gm)];
  if (imports.length > 0) {
    const last = imports.at(-1);
    const at = last.index + last[0].length;
    source = source.slice(0, at) + "\n" + importLine + source.slice(at);
  } else {
    source = importLine + "\n" + source;
  }
  await fs.writeFile(target, source, "utf8");
  console.log(`PATCHED: ${path.relative(root, target)} imports ${specifier}`);
} else {
  console.log("PASS: learner CSS already imported by Learner/Journey story");
}
