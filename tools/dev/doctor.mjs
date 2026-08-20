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


/**
 * Windows:
 * Use the normal shell so pnpm/git command shims resolve exactly
 * as they do in the user's terminal.
 *
 * Non-Windows:
 * Execute the binary directly.
 *
 * Commands and args here are internal constants only; no untrusted
 * user-supplied input is passed to the shell.
 */
function runTool(
  command,
  args = []
) {
  if (
    process.platform ===
    "win32"
  ) {
    const commandLine =
      [
        command,
        ...args
      ]
        .join(
          " "
        );

    return execSync(
      commandLine,
      {
        cwd:
          repoRoot,

        encoding:
          "utf8",

        stdio: [
          "ignore",
          "pipe",
          "pipe"
        ],

        shell:
          process.env.ComSpec ||
          "C:\\Windows\\System32\\cmd.exe"
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
  ".nvmrc",
  ".env.example",
  ".gitattributes",
  "DEVELOPMENT.md",
  "bootstrap-dev.cmd",
  "tools/dev/bootstrap-dev.ps1",
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
  }
  else {
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
  }
  else {
    fail(
      `Node mismatch: expected ${expectedNode}, actual ${actualNode}`
    );
  }
}
catch (
  error
) {
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
  }
  else {
    fail(
      `pnpm mismatch: expected ${expectedPnpm}, actual ${actualPnpm}`
    );
  }
}
catch (
  error
) {
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
  }
  else {
    fail(
      `secret files tracked by Git: ${trackedSecrets}`
    );
  }
}
catch (
  error
) {
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
}
catch {
  fail(
    "content compiler output is out of date"
  );
}


try {
  const envExample =
    readText(
      ".env.example"
    );

  const suspicious =
    envExample
      .split(
        /\r?\n/
      )
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
  }
  else {
    fail(
      ".env.example appears to contain real values"
    );
  }
}
catch (
  error
) {
  fail(
    `.env.example check failed: ${error.message}`
  );
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
