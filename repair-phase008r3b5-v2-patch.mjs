import fs from "node:fs/promises";
import path from "node:path";

const file = path.join(process.cwd(), "apps/learner-web/src/features/play/ActivityPlayer.tsx");
let source = await fs.readFile(file, "utf8");

const marker = 'data-testid="activity-player"';
const markerIndex = source.indexOf(marker);
if (markerIndex < 0) throw new Error("activity-player marker missing");

const opening = source.lastIndexOf("<main", markerIndex);
if (opening >= 0) {
  const closing = source.indexOf("</main>", markerIndex);
  if (closing < 0) throw new Error("ActivityPlayer closing </main> missing");
  source =
    source.slice(0, opening) +
    "<section" +
    source.slice(opening + 5, closing) +
    "</section>" +
    source.slice(closing + 7);
  await fs.writeFile(file, source, "utf8");
  console.log("PATCHED: ActivityPlayer nested main landmark changed to section");
} else {
  const sectionOpening = source.lastIndexOf("<section", markerIndex);
  if (sectionOpening < 0) {
    throw new Error("ActivityPlayer wrapper is neither expected main nor repaired section");
  }
  console.log("PASS: ActivityPlayer landmark already repaired");
}
