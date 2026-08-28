import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const manifestRoot = path.join(root, "assets", "manifests");
const briefRoot = path.join(root, "assets", "briefs");
const queueRoot = path.join(root, "assets", "production-queue");

fs.mkdirSync(briefRoot, { recursive: true });
fs.mkdirSync(queueRoot, { recursive: true });

const files = fs.readdirSync(manifestRoot)
  .filter(file => file.endsWith(".json"))
  .sort();

const queue = [];

for (const file of files) {
  const manifest = JSON.parse(
    fs.readFileSync(path.join(manifestRoot, file), "utf8")
  );

  if (manifest.replacementRequiredForCommercialRelease !== true) continue;

  const existing = path.join(briefRoot, `${manifest.id}.json`);

  if (!fs.existsSync(existing)) {
    const subject =
      manifest.id
        .replace(/^obj-/, "")
        .replaceAll("-", " ");

    const brief = {
      schemaVersion: 1,
      assetId: manifest.id,
      curriculumPurpose:
        `Replace prototype ${manifest.id} with an original HIBEYA production asset.`,
      ageBands: ["4-5", "6-7"],
      subject,
      interactionRole: "learning-object",
      visualBrief: {
        description:
          `Original child-readable HIBEYA illustration of ${subject}, designed as a clear learning object.`,
        composition:
          "Single dominant object with strong silhouette and generous negative space.",
        background:
          "transparent",
        avoid: [
          "text",
          "logos",
          "watermarks",
          "protected characters",
          "celebrity likenesses",
          "photorealistic clutter",
          "unnecessary decorative detail"
        ]
      },
      malaysianContext: [],
      culturalReviewRequired: false,
      variants: ["default"],
      masterFormat: "svg",
      runtimeFormats: ["svg", "webp"],
      productionMethod: "original-ai-assisted",
      status: "draft"
    };

    fs.writeFileSync(
      existing,
      JSON.stringify(brief, null, 2) + "\n",
      "utf8"
    );
  }

  queue.push({
    assetId: manifest.id,
    manifest: `assets/manifests/${manifest.id}.json`,
    brief: `assets/briefs/${manifest.id}.json`,
    priority: "replace-prototype",
    status: "brief-ready"
  });
}

const queueFile = path.join(queueRoot, "learner-core.json");

fs.writeFileSync(
  queueFile,
  JSON.stringify({
    schemaVersion: 1,
    queueId: "learner-core",
    generatedFrom: "assets/manifests",
    items: queue
  }, null, 2) + "\n",
  "utf8"
);

console.log(`ASSET PRODUCTION QUEUE: ${queue.length} replacement assets`);
