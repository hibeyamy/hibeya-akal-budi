import fs from "node:fs/promises";
import path from "node:path";

const root = process.cwd();
const story = path.join(root, "apps", "ui-storybook", "stories", "LearnerJourney.stories.tsx");
const preview = path.join(root, "apps", "ui-storybook", ".storybook", "preview.ts");
const previewTsx = path.join(root, "apps", "ui-storybook", ".storybook", "preview.tsx");

const learnerCssImportInStory = `import "../../learner-web/src/index.css";`;
let storySource = await fs.readFile(story, "utf8");

if (storySource.includes(learnerCssImportInStory)) {
  storySource = storySource.replace(learnerCssImportInStory + "\n", "");
  storySource = storySource.replace(learnerCssImportInStory + "\r\n", "");
  storySource = storySource.replace(learnerCssImportInStory, "");
  await fs.writeFile(story, storySource, "utf8");
  console.log("PATCHED: removed cross-package CSS side-effect import from LearnerJourney story");
} else {
  console.log("PASS: story-level learner CSS import already absent");
}

let previewFile = null;
try { await fs.access(previewTsx); previewFile = previewTsx; } catch {}
if (!previewFile) {
  try { await fs.access(preview); previewFile = preview; } catch {}
}
if (!previewFile) throw new Error("Storybook preview.ts/preview.tsx not found.");

let previewSource = await fs.readFile(previewFile, "utf8");
const rel = path.relative(path.dirname(previewFile), path.join(root, "apps", "learner-web", "src", "index.css")).replaceAll("\\", "/");
const specifier = rel.startsWith(".") ? rel : "./" + rel;
const importLine = `import "${specifier}";`;

if (!previewSource.includes(importLine)) {
  previewSource = importLine + "\n" + previewSource;
  await fs.writeFile(previewFile, previewSource, "utf8");
  console.log(`PATCHED: Storybook preview imports ${specifier}`);
} else {
  console.log("PASS: Storybook preview already imports learner stylesheet");
}
