import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const metadata = {
  "apple-red": {
    alt: {
      ms: "Epal merah",
      en: "Red apple"
    }
  },
  "apple-green": {
    alt: {
      ms: "Epal hijau",
      en: "Green apple"
    }
  },
  "banana-yellow": {
    alt: {
      ms: "Pisang kuning",
      en: "Yellow banana"
    }
  }
};

for (const [id, runtime] of Object.entries(metadata)) {
  const file =
    path.join(
      root,
      "assets",
      "manifests",
      `${id}.json`
    );

  if (!fs.existsSync(file)) {
    console.error(`Missing approved manifest: ${id}`);
    process.exit(1);
  }

  const manifest =
    JSON.parse(
      fs.readFileSync(
        file,
        "utf8"
      )
    );

  if (manifest.commercialReady !== true) {
    console.error(
      `${id}: expected commercialReady=true before registry migration`
    );

    process.exit(1);
  }

  manifest.runtime = {
    ...(manifest.runtime ?? {}),
    alt: runtime.alt,
    file: `packages/assets/src/generated/${id}.svg`
  };

  fs.writeFileSync(
    file,
    JSON.stringify(
      manifest,
      null,
      2
    ) + "\n",
    "utf8"
  );
}

console.log(
  "COMMERCIAL RUNTIME METADATA: migrated 3 approved assets"
);
