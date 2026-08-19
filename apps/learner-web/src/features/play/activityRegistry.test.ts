import {
  describe,
  expect,
  it
} from "vitest";

import {
  getActivityImplementation,
  hasActivityImplementation
} from "./activityRegistry";

import {
  resolveRuntimeActivity
} from "./resolvePlayableActivity";


describe(
  "learner activity registry",
  () => {

    it(
      "resolves colour-choice-v1",
      () => {
        const implementation =
          getActivityImplementation(
            "colour-choice-v1"
          );


        expect(
          implementation
        ).not.toBeNull();

        expect(
          implementation
            ?.implementationKey
        ).toBe(
          "colour-choice-v1"
        );
      }
    );


    it(
      "returns null for an unknown implementation",
      () => {
        expect(
          getActivityImplementation(
            "does-not-exist"
          )
        ).toBeNull();
      }
    );


    it(
      "reports registered implementations",
      () => {
        expect(
          hasActivityImplementation(
            "colour-choice-v1"
          )
        ).toBe(true);


        expect(
          hasActivityImplementation(
            "unknown"
          )
        ).toBe(false);
      }
    );


    it(
      "resolves playable catalogue activity to runtime implementation",
      () => {
        const runtime =
          resolveRuntimeActivity(
            "warna-merah-001"
          );


        expect(runtime)
          .not.toBeNull();


        expect(
          runtime
            ?.catalogue
            .id
        ).toBe(
          "warna-merah-001"
        );


        expect(
          runtime
            ?.catalogue
            .implementationKey
        ).toBe(
          "colour-choice-v1"
        );


        expect(
          runtime
            ?.implementation
            .implementationKey
        ).toBe(
          "colour-choice-v1"
        );
      }
    );


    it(
      "returns null for unknown playable activity",
      () => {
        expect(
          resolveRuntimeActivity(
            "unknown-activity"
          )
        ).toBeNull();
      }
    );

  }
);
