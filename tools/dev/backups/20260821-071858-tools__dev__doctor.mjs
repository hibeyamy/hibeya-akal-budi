import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import {
  execFileSync,
  execSync
} from "node:child_process";


const repoRoot =
  process.cwd();


const failures =
  [];


function pass(
  message
) {
  console.log(
    `PASS  ${message}`
  );
}


function fail(
  message
) {
  console.error(
    `FAIL  ${message}`
  );

  failures.push(
    message
  );
}


function readText(
  relativePath
) {
  return fs.readFileSync(
    path.join(
      repoRoot,
      relativePath
    ),
    "utf8"
  );
}


function exists(
  relativePath
) {
  return fs.existsSync(
    path.join(
      repoRoot,
      relativePath
    )
  );
}


/**
 * Executes a tool in a cross-platform way.
 *
 * Windows .cmd shims such as pnpm.cmd cannot always be launched
 * directly by execFileSync on newer Node/Windows combinations.
 * Use cmd.exe explicitly on Windows and execFileSync elsewhere.
 */
function runTool(
  command,
  args = []
) {
  if (
    process.platform ===
    "win32"
  ) {
    const quoted =
      [
        command,
        ...args
      ]
        .map(
          value =>
            `"${String(value).replace(/"/g, '""')}"`
        )
        .join(
          " "
        );

    return execFileSync(
      "cmd.exe",
      [
        "/d",
        "/s",
        "/c",
        quoted
      ],
      {
        cwd:
          repoRoot,

        encoding:
          "utf8",

        stdio: [
          "ignore",
          "pipe",
          "pipe"
        ]
      }
    ).trim();
  }


  return execFileSync(
    command,
    args,
    {
      cwd:
        repoRoot,

      encoding:
        "utf8",

      stdio: [
        "ignore",
        "pipe",
        "pipe"
      ]
    }
  ).trim();
}


console.log(
  "HIBEYA AKAL BUDI PROJECT DOCTOR"
);

console.log(
  "================================"
);


const requiredFiles = [
  "package.json",
  "pnpm-lock.yaml",
  "pnpm-workspace.yaml",
  ".node-version",
  ".env.example",
  ".gitattributes",
  "tools/content-compiler/compile.mjs",
  "apps/learner-web/package.json",
  "apps/parent-web/package.json",
  "supabase/config.toml"
];


for (
  const file
  of requiredFiles
) {
  if (
    exists(
      file
    )
  ) {
    pass(
      `required file: ${file}`
    );
  } else {
    fail(
      `missing required file: ${file}`
    );
  }
}


try {
  const expectedNode =
    readText(
      ".node-version"
    ).trim();

  const actualNode =
    process.version;

  if (
    actualNode ===
    expectedNode
  ) {
    pass(
      `Node ${actualNode}`
    );
  } else {
    fail(
      `Node mismatch: expected ${expectedNode}, actual ${actualNode}`
    );
  }
} catch (error) {
  fail(
    `Node check failed: ${error.message}`
  );
}


try {
  const packageJson =
    JSON.parse(
      readText(
        "package.json"
      )
    );

  const expectedPnpm =
    String(
      packageJson.packageManager ??
      ""
    )
      .replace(
        /^pnpm@/,
        ""
      );

  const actualPnpm =
    runTool(
      "pnpm",
      [
        "--version"
      ]
    );

  if (
    expectedPnpm ===
    actualPnpm
  ) {
    pass(
      `pnpm ${actualPnpm}`
    );
  } else {
    fail(
      `pnpm mismatch: expected ${expectedPnpm}, actual ${actualPnpm}`
    );
  }
} catch (error) {
  fail(
    `pnpm check failed: ${error.message}`
  );
}


try {
  const trackedSecrets =
    runTool(
      "git",
      [
        "ls-files",
        ".env",
        ".env.local",
        ".env.security.local"
      ]
    );

  if (
    trackedSecrets.length ===
    0
  ) {
    pass(
      "no known local secret files tracked"
    );
  } else {
    fail(
      `secret files tracked by Git: ${trackedSecrets}`
    );
  }
} catch (error) {
  fail(
    `Git secret check failed: ${error.message}`
  );
}


try {
  runTool(
    "node",
    [
      "tools/content-compiler/compile.mjs",
      "--check"
    ]
  );

  pass(
    "content compiler reproducibility"
  );
} catch {
  fail(
    "content compiler output is out of date"
  );
}


const examplePath =
  path.join(
    repoRoot,
    ".env.example"
  );


if (
  fs.existsSync(
    examplePath
  )
) {
  const envExample =
    fs.readFileSync(
      examplePath,
      "utf8"
    );

  const suspicious =
    envExample
      .split(/\r?\n/)
      .filter(
        line =>
          /^[A-Z][A-Z0-9_]+=.+/.test(
            line
          )
      );

  if (
    suspicious.length ===
    0
  ) {
    pass(
      ".env.example contains no values"
    );
  } else {
    fail(
      ".env.example appears to contain real values"
    );
  }
}


if (
  failures.length >
  0
) {
  console.error("");
  console.error(
    `PROJECT DOCTOR: FAIL (${failures.length})`
  );

  process.exit(1);
}


console.log("");
console.log(
  "PROJECT DOCTOR: PASS"
);
