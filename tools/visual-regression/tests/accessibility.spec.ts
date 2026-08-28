import {
  expect,
  test
} from "@playwright/test";

import AxeBuilder
  from "@axe-core/playwright";


const stories = [
  {
    name:
      "Learner audience",

    id:
      "foundations-audience--learner"
  },
  {
    name:
      "Parent audience",

    id:
      "foundations-audience--parent"
  },
  {
    name:
      "Primary button",

    id:
      "primitives-button--primary"
  },
  {
    name:
      "Gentle feedback",

    id:
      "primitives-feedbackpanel--gentle"
  }
];


for (
  const story
  of stories
) {
  test(
    `${story.name} has no serious axe violations`,
    async ({
      page
    }) => {
      await page.goto(
        `/iframe.html?id=${story.id}&viewMode=story`
      );

      await page.waitForLoadState(
        "networkidle"
      );

      const results =
        await new AxeBuilder({
          page
        })
          .withTags([
            "wcag2a",
            "wcag2aa",
            "wcag21a",
            "wcag21aa"
          ])
          .analyze();

      const serious =
        results.violations
          .filter(
            violation =>
              [
                "serious",
                "critical"
              ].includes(
                violation.impact ??
                ""
              )
          );

      expect(
        serious,
        JSON.stringify(
          serious,
          null,
          2
        )
      ).toEqual([]);
    }
  );
}


test(
  "learner buttons meet preferred 56px touch target",
  async ({
    page
  }) => {
    await page.goto(
      "/iframe.html?id=primitives-button--primary&viewMode=story"
    );

    const button =
      page.getByRole(
        "button",
        {
          name:
            "Aktiviti seterusnya"
        }
      );

    await expect(
      button
    ).toBeVisible();

    const dimensions =
      await button.evaluate(
        element => {
          const rect =
            element.getBoundingClientRect();

          return {
            width:
              rect.width,

            height:
              rect.height
          };
        }
      );

    expect(
      dimensions.height
    ).toBeGreaterThanOrEqual(
      56
    );

    expect(
      dimensions.width
    ).toBeGreaterThanOrEqual(
      56
    );
  }
);


test(
  "reduced motion suppresses meaningful transitions",
  async ({
    page
  }) => {
    await page.goto(
      "/iframe.html?id=primitives-button--primary&viewMode=story"
    );

    const button =
      page.locator(
        "button"
      ).first();

    const transitionDuration =
      await button.evaluate(
        element =>
          getComputedStyle(
            element
          ).transitionDuration
      );

    const durations =
      transitionDuration
        .split(",")
        .map(
          value =>
            value.trim()
        );

    for (
      const duration
      of durations
    ) {
      const seconds =
        duration.endsWith(
          "ms"
        )
          ? Number.parseFloat(
              duration
            ) /
            1000
          : Number.parseFloat(
              duration
            );

      expect(
        Number.isNaN(
          seconds
        )
          ? 0
          : seconds
      ).toBeLessThanOrEqual(
        0.05
      );
    }
  }
);
