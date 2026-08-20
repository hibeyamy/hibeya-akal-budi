import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";


const repoRoot =
  process.cwd();


function pass(message) {
  console.log(
    `PASS  ${message}`
  );
}


function fail(message) {
  console.error(
    `FAIL  ${message}`
  );

  failures.push(
    message
  );
}


function readText(relativePath) {
  return fs.readFileSync(
    path.join(
      repoRoot,
      relativePath
    ),
    "utf8"
  );
}


function exists(relativePath) {
  return fs.existsSync(
    path.join(
      repoRoot,
      relativePath
    )
  );
}


function run(
  command,
  args
) {
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


const failures =
  [];


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
    run(
      process.platform ===
        "win32"
        ? "pnpm.cmd"
        : "pnpm",
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
    run(
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
  run(
    "node",
    [
      "tools/content-compiler/compile.mjs",
      "--check"
    ]
  );

  pass(
    "content compiler reproducibility"
  );
} catch (error) {
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
