import {
  describe,
  expect,
  it
} from "vitest";

import {
  designTokens,
  getAudienceDesignContract,
  wellbeingDesignRules
} from "../index";


describe(
  "design-system foundation",
  () => {

    it(
      "keeps learner touch targets larger than parent minimums",
      () => {

        const learner =
          getAudienceDesignContract(
            "learner"
          );

        const parent =
          getAudienceDesignContract(
            "parent"
          );


        expect(
          learner.minimumTouchTargetPx
        ).toBeGreaterThan(
          parent.minimumTouchTargetPx
        );
      }
    );


    it(
      "forbids pressure-based learner interaction patterns",
      () => {

        expect(
          wellbeingDesignRules
            .streakPressureAllowed
        ).toBe(false);

        expect(
          wellbeingDesignRules
            .lossAversionAllowed
        ).toBe(false);

        expect(
          wellbeingDesignRules
            .countdownPressureAllowed
        ).toBe(false);

        expect(
          wellbeingDesignRules
            .infiniteScrollAllowed
        ).toBe(false);
      }
    );


    it(
      "requires reduced-motion support",
      () => {

        expect(
          designTokens
            .wellbeing
            .reducedMotionRequired
        ).toBe(true);
      }
    );


    it(
      "keeps focus indication explicit",
      () => {

        expect(
          designTokens
            .interaction
            .focusRingPx
        ).toBeGreaterThanOrEqual(
          2
        );
      }
    );

  }
);
