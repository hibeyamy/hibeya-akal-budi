import fs from "node:fs";
import path from "node:path";
import process from "node:process";


const repoRoot =
  process.cwd();

const policy =
  JSON.parse(
    fs.readFileSync(
      path.join(
        repoRoot,
        "design",
        "design-policy.json"
      ),
      "utf8"
    )
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
    `DESIGN POLICY ERROR: ${message}`
  );
}


if (
  policy.principles
    ?.childWellbeingFirst !==
  true
) {
  fail(
    "childWellbeingFirst must remain true"
  );
}


if (
  policy.principles
    ?.noBehaviouralDarkPatterns !==
  true
) {
  fail(
    "noBehaviouralDarkPatterns must remain true"
  );
}


if (
  policy.principles
    ?.reducedMotionRequired !==
  true
) {
  fail(
    "reducedMotionRequired must remain true"
  );
}


if (
  Number(
    policy.learner
      ?.minimumTouchTargetPx
  ) <
  44
) {
  fail(
    "learner minimum touch target must be at least 44px"
  );
}


if (
  Number(
    policy.parent
      ?.minimumTouchTargetPx
  ) <
  44
) {
  fail(
    "parent minimum touch target must be at least 44px"
  );
}


const requiredForbidden =
  [
    "streak-pressure",
    "loss-aversion",
    "countdown-pressure",
    "infinite-scroll",
    "behavioural-advertising"
  ];


for (
  const item
  of requiredForbidden
) {
  if (
    !policy.forbiddenPatterns
      ?.includes(
        item
      )
  ) {
    fail(
      `required forbidden pattern missing: ${item}`
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
  "DESIGN POLICY VALIDATION: PASS"
);
