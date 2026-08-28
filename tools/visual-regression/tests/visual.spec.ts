import {
  expect,
  test
} from "@playwright/test";


const visualStories = [
  {
    name:
      "learner-audience",

    id:
      "foundations-audience--learner"
  },
  {
    name:
      "parent-audience",

    id:
      "foundations-audience--parent"
  },
  {
    name:
      "button-primary",

    id:
      "primitives-button--primary"
  },
  {
    name:
      "button-secondary",

    id:
      "primitives-button--secondary"
  },
  {
    name:
      "feedback-success",

    id:
      "primitives-feedbackpanel--success"
  },
  {
    name:
      "feedback-gentle",

    id:
      "primitives-feedbackpanel--gentle"
  }
];


for (
  const story
  of visualStories
) {
  test(
    `${story.name} visual baseline`,
    async ({
      page
    }) => {
      await page.goto(
        `/iframe.html?id=${story.id}&viewMode=story`
      );

      await page.waitForLoadState(
        "networkidle"
      );

      await expect(
        page
      ).toHaveScreenshot(
        `${story.name}.png`,
        {
          fullPage:
            true
        }
      );
    }
  );
}
