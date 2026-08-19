import {
  describe,
  expect,
  it
} from "vitest";

import {
  activityBlueprints
} from "../blueprints";

import {
  ageBandProfiles
} from "../ageBands";

import {
  contentThemes
} from "../themes";

import {
  validateContentArchitecture
} from "../validate";


describe(
  "Akal Budi content architecture",
  () => {

    it(
      "defines all four age bands",
      () => {
        expect(
          ageBandProfiles
            .map(
              item =>
                item.ageBand
            )
            .sort()
        ).toEqual(
          [
            "2-3",
            "3-4",
            "4-5",
            "5-6"
          ].sort()
        );
      }
    );


    it(
      "does not claim curriculum mapping for under-four age bands",
      () => {
        const younger =
          ageBandProfiles.filter(
            profile =>
              profile.ageBand ===
                "2-3" ||
              profile.ageBand ===
                "3-4"
          );


        expect(
          younger.every(
            profile =>
              profile
                .curriculumPosition ===
              "developmentally-informed"
          )
        ).toBe(true);
      }
    );


    it(
      "provides Malaysian context across all themes",
      () => {
        expect(
          contentThemes.every(
            theme =>
              theme
                .malaysiaElements
                .length > 0
          )
        ).toBe(true);
      }
    );


    it(
      "provides originality and healthy-use rationale for every activity",
      () => {
        expect(
          activityBlueprints.every(
            activity =>
              activity
                .originalityNote
                .length > 20 &&
              activity
                .healthyUseNote
                .length > 20
          )
        ).toBe(true);
      }
    );


    it(
      "passes architecture validation",
      () => {
        expect(
          validateContentArchitecture()
        ).toEqual([]);
      }
    );

  }
);
