import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const [
  ,
  ,
  sourceId,
  localFile
] =
  process.argv;


if (
  !sourceId ||
  !localFile
) {
  console.error(
    "Usage: node tools/curriculum/capture-source.mjs <source-id> <local-file>"
  );

  process.exit(1);
}


const repoRoot =
  process.cwd();

const registryPath =
  path.join(
    repoRoot,
    "content",
    "curriculum",
    "source-registry.json"
  );

const sourceCacheRoot =
  path.join(
    repoRoot,
    "content",
    "curriculum",
    "source-cache"
  );


const resolvedFile =
  path.resolve(
    localFile
  );


if (
  !fs.existsSync(
    resolvedFile
  )
) {
  console.error(
    `Local source file not found: ${resolvedFile}`
  );

  process.exit(1);
}


const registry =
  JSON.parse(
    fs.readFileSync(
      registryPath,
      "utf8"
    )
  );


const source =
  registry.sources.find(
    item =>
      item.id ===
      sourceId
  );


if (!source) {
  console.error(
    `Unknown source ID: ${sourceId}`
  );

  process.exit(1);
}


const bytes =
  fs.readFileSync(
    resolvedFile
  );


const sha256 =
  crypto
    .createHash(
      "sha256"
    )
    .update(
      bytes
    )
    .digest(
      "hex"
    );


fs.mkdirSync(
  sourceCacheRoot,
  {
    recursive:
      true
  }
);


const extension =
  path.extname(
    resolvedFile
  )
    .toLowerCase();


const cachedFile =
  path.join(
    sourceCacheRoot,
    `${sourceId}${extension}`
  );


fs.copyFileSync(
  resolvedFile,
  cachedFile
);


source.documentSha256 =
  sha256;

source.verificationStatus =
  "document-verified";


fs.writeFileSync(
  registryPath,
  JSON.stringify(
    registry,
    null,
    2
  ) +
  "\n",
  "utf8"
);


console.log(
  `CAPTURED: ${sourceId}`
);

console.log(
  `SHA256: ${sha256}`
);

console.log(
  "The cached source document is local-only and must remain ignored by Git."
);
