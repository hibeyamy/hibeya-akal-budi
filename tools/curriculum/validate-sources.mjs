import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const repoRoot =
  process.cwd();


function readJson(
  relativePath
) {
  return JSON.parse(
    fs.readFileSync(
      path.join(
        repoRoot,
        relativePath
      ),
      "utf8"
    )
  );
}


const registry =
  readJson(
    "content/curriculum/source-registry.json"
  );


const failures =
  [];


function fail(
  message
) {
  failures.push(
    message
  );

  console.error(
    `SOURCE REGISTRY ERROR: ${message}`
  );
}


if (
  !Array.isArray(
    registry.authorities
  )
) {
  fail(
    "authorities[] is required"
  );
}


if (
  !Array.isArray(
    registry.sources
  )
) {
  fail(
    "sources[] is required"
  );
}


const authorityMap =
  new Map(
    (
      registry.authorities ??
      []
    )
      .map(
        authority => [
          authority.id,
          authority
        ]
      )
  );


const ids =
  (
    registry.sources ??
    []
  )
    .map(
      source =>
        source.id
    );


if (
  new Set(
    ids
  ).size !==
    ids.length
) {
  fail(
    "Duplicate source IDs are not allowed"
  );
}


for (
  const source
  of registry.sources ??
  []
) {
  const authority =
    authorityMap.get(
      source.authorityId
    );


  if (!authority) {
    fail(
      `${source.id}: unknown authority ${source.authorityId}`
    );

    continue;
  }


  let url;

  try {
    url =
      new URL(
        source.sourceUrl
      );
  }
  catch {
    fail(
      `${source.id}: invalid sourceUrl`
    );

    continue;
  }


  const allowed =
    authority.officialDomains
      .some(
        domain =>
          url.hostname ===
            domain ||
          url.hostname.endsWith(
            `.${domain}`
          )
      );


  if (!allowed) {
    fail(
      `${source.id}: URL is outside the authority's official domains`
    );
  }


  if (
    ![
      "unverified",
      "metadata-verified",
      "document-verified",
      "superseded"
    ].includes(
      source.verificationStatus
    )
  ) {
    fail(
      `${source.id}: invalid verificationStatus`
    );
  }


  if (
    source.verificationStatus ===
      "document-verified"
  ) {
    if (
      typeof source.documentSha256 !==
        "string" ||
      !/^[a-f0-9]{64}$/.test(
        source.documentSha256
      )
    ) {
      fail(
        `${source.id}: document-verified sources require a SHA-256 hash`
      );
    }
  }


  if (
    source.documentSha256 !==
      null &&
    (
      typeof source.documentSha256 !==
        "string" ||
      !/^[a-f0-9]{64}$/.test(
        source.documentSha256
      )
    )
  ) {
    fail(
      `${source.id}: documentSha256 must be null or a lowercase SHA-256 hash`
    );
  }
}


if (
  failures.length >
  0
) {
  process.exit(1);
}


console.log(
  `CURRICULUM SOURCE REGISTRY: PASS (${registry.sources.length} sources)`
);
