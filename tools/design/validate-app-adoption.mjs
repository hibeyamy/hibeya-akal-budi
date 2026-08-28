import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root =
  process.cwd();

const apps = [
  {
    id:
      "learner",

    root:
      path.join(
        root,
        "apps",
        "learner-web",
        "src"
      ),

    audience:
      "learner"
  },
  {
    id:
      "parent",

    root:
      path.join(
        root,
        "apps",
        "parent-web",
        "src"
      ),

    audience:
      "parent"
  }
];

const failures = [];

function fail(
  message
) {
  failures.push(
    message
  );

  console.error(
    `DESIGN ADOPTION ERROR: ${message}`
  );
}

function sourceFiles(
  directory
) {
  const result = [];

  for (
    const entry
    of fs.readdirSync(
      directory,
      {
        withFileTypes:
          true
      }
    )
  ) {
    const full =
      path.join(
        directory,
        entry.name
      );

    if (
      entry.isDirectory()
    ) {
      result.push(
        ...sourceFiles(
          full
        )
      );

      continue;
    }

    if (
      /\.(ts|tsx)$/.test(
        entry.name
      )
    ) {
      result.push(
        full
      );
    }
  }

  return result;
}

for (
  const app
  of apps
) {
  if (
    !fs.existsSync(
      app.root
    )
  ) {
    fail(
      `${app.id}: source root missing`
    );

    continue;
  }

  const files =
    sourceFiles(
      app.root
    );

  const all =
    files
      .map(
        file =>
          fs.readFileSync(
            file,
            "utf8"
          )
      )
      .join(
        "\n"
      );

  if (
    !all.includes(
      '@akal-budi/design-system/tokens.css'
    )
  ) {
    fail(
      `${app.id}: semantic token CSS is not imported`
    );
  }

  if (
    !all.includes(
      '@akal-budi/ui/styles.css'
    )
  ) {
    fail(
      `${app.id}: shared UI CSS is not imported`
    );
  }

  const audienceMarker =
    `dataset.abAudience = "${app.audience}"`;

  if (
    !all.includes(
      audienceMarker
    )
  ) {
    fail(
      `${app.id}: expected audience marker ${app.audience}`
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
  "APP DESIGN ADOPTION: PASS"
);
