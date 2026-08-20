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
      "resolves existing colour activity",
      () => {
        const implementation =
          getActivityImplementation(
            "warna-merah-001",
            "colour-choice-v1"
          );


        expect(
          implementation
        ).not.toBeNull();


        expect(
          implementation
            ?.activity.id
        ).toBe(
          "warna-merah-001"
        );
      }
    );


    it(
      "resolves bunga raya activity",
      () => {
        const implementation =
          getActivityImplementation(
            "warna-bunga-raya-001",
            "colour-choice-v1"
          );


        expect(
          implementation
        ).not.toBeNull();


        expect(
          implementation
            ?.activity.id
        ).toBe(
          "warna-bunga-raya-001"
        );
      }
    );


    it(
      "does not confuse activities that share the same implementation key",
      () => {
        const oldActivity =
          getActivityImplementation(
            "warna-merah-001",
            "colour-choice-v1"
          );


        const bungaRaya =
          getActivityImplementation(
            "warna-bunga-raya-001",
            "colour-choice-v1"
          );


        expect(
          oldActivity
            ?.activity.id
        ).not.toBe(
          bungaRaya
            ?.activity.id
        );
      }
    );


    it(
      "returns null for an unknown implementation",
      () => {
        expect(
          getActivityImplementation(
            "warna-bunga-raya-001",
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
            "warna-bunga-raya-001",
            "colour-choice-v1"
          )
        ).toBe(true);


        expect(
          hasActivityImplementation(
            "unknown",
            "colour-choice-v1"
          )
        ).toBe(false);
      }
    );


    it(
      "resolves existing playable activity through runtime",
      () => {
        const runtime =
          resolveRuntimeActivity(
            "warna-merah-001"
          );


        expect(runtime)
          .not.toBeNull();


        expect(
          runtime
            ?.implementation
            .activity.id
        ).toBe(
          "warna-merah-001"
        );
      }
    );


    it(
      "resolves Malaysian playable activity through runtime",
      () => {
        const runtime =
          resolveRuntimeActivity(
            "warna-bunga-raya-001"
          );


        expect(runtime)
          .not.toBeNull();


        expect(
          runtime
            ?.catalogue
            .blueprintId
        ).toBe(
          "warna-bunga-raya"
        );


        expect(
          runtime
            ?.implementation
            .activity.id
        ).toBe(
          "warna-bunga-raya-001"
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
