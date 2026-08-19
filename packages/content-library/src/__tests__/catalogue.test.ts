import {
  describe,
  expect,
  it
} from "vitest";

import {
  getPlayableActivitiesForAgeBand,
  getPlayableActivity,
  playableActivities
} from "../catalogue";

import {
  validatePlayableCatalogue
} from "../validateCatalogue";


describe(
  "Akal Budi playable content catalogue",
  () => {

    it(
      "contains at least one playable activity",
      () => {
        expect(
          playableActivities.length
        ).toBeGreaterThan(0);
      }
    );


    it(
      "resolves the existing colour activity to its blueprint",
      () => {
        const activity =
          getPlayableActivity(
            "warna-merah-001"
          );


        expect(activity)
          .not.toBeNull();

        expect(
          activity?.blueprintId
        ).toBe(
          "warna-bunga-raya"
        );

        expect(
          activity?.blueprint.id
        ).toBe(
          "warna-bunga-raya"
        );
      }
    );


    it(
      "returns null for an unknown activity",
      () => {
        expect(
          getPlayableActivity(
            "does-not-exist"
          )
        ).toBeNull();
      }
    );


    it(
      "returns age-appropriate activities",
      () => {
        const activities =
          getPlayableActivitiesForAgeBand(
            "3-4"
          );


        expect(
          activities.some(
            (activity) =>
              activity.id ===
              "warna-merah-001"
          )
        ).toBe(true);


        expect(
          activities.every(
            (activity) =>
              activity.ageBands.includes(
                "3-4"
              )
          )
        ).toBe(true);
      }
    );


    it(
      "does not expose the colour activity to unsupported older age bands",
      () => {
        const activities =
          getPlayableActivitiesForAgeBand(
            "5-6"
          );


        expect(
          activities.some(
            (activity) =>
              activity.id ===
              "warna-merah-001"
          )
        ).toBe(false);
      }
    );


    it(
      "passes playable catalogue validation",
      () => {
        expect(
          validatePlayableCatalogue()
        ).toEqual([]);
      }
    );

  }
);
