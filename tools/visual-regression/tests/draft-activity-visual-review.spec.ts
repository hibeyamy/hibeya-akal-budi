import {
  expect,
  test
} from "@playwright/test";


const storyId =
  "review-draft-activity--beza-bunga-raya-001";


async function openReview(
  page:
    import("@playwright/test").Page
) {
  const response =
    await page.goto(
      `/iframe.html?id=${storyId}&viewMode=story`,
      {
        waitUntil:
          "domcontentloaded"
      }
    );

  expect(
    response?.ok(),
    `Storybook iframe HTTP failure for ${storyId}`
  ).toBeTruthy();

  await expect(
    page.locator(
      '[data-review-activity-id="beza-bunga-raya-001"]'
    )
  ).toBeVisible();
}


test.describe(
  "draft activity visual review",
  () => {
    test(
      "renders the governed three-choice contract without production state",
      async ({
        page
      }) => {
        await openReview(
          page
        );

        await expect(
          page.getByText(
            "Draf - semakan visual sahaja"
          )
        ).toBeVisible();

        await expect(
          page.getByRole(
            "heading",
            {
              name:
                "Yang Mana Berbeza?"
            }
          )
        ).toBeVisible();

        await expect(
          page.getByText(
            "Cari bunga raya yang berbeza"
          )
        ).toBeVisible();

        const choices =
          page.getByTestId(
            "draft-choice"
          );

        await expect(
          choices
        ).toHaveCount(
          3
        );

        await expect(
          page.locator(
            '[data-asset-id="hibiscus-red"]'
          )
        ).toHaveCount(
          2
        );

        await expect(
          page.locator(
            '[data-asset-id="hibiscus-yellow"]'
          )
        ).toHaveCount(
          1
        );

        await expect(
          page.locator(
            '[data-testid="draft-choice"][data-correct="true"]'
          )
        ).toHaveCount(
          1
        );

        await page.locator(
          '[data-testid="draft-choice"][data-correct="false"]'
        ).first().click();

        await expect(
          page.getByText(
            "Cuba lagi."
          )
        ).toBeVisible();

        await page.locator(
          '[data-testid="draft-choice"][data-correct="true"]'
        ).click();

        await expect(
          page.getByText(
            "Betul! Bagus."
          )
        ).toBeVisible();
      }
    );


    for (
      const viewport of [
        {
          name:
            "mobile",
          width:
            390,
          height:
            844
        },
        {
          name:
            "tablet",
          width:
            768,
          height:
            1024
        },
        {
          name:
            "desktop",
          width:
            1440,
          height:
            1000
        }
      ]
    ) {
      test(
        `meets visual and touch-target contract on ${viewport.name}`,
        async ({
          page
        }) => {
          await page.setViewportSize({
            width:
              viewport.width,
            height:
              viewport.height
          });

          await openReview(
            page
          );

          const choices =
            page.getByTestId(
              "draft-choice"
            );

          await expect(
            choices
          ).toHaveCount(
            3
          );

          for (
            let index = 0;
            index < 3;
            index += 1
          ) {
            const box =
              await choices
                .nth(index)
                .boundingBox();

            expect(
              box,
              `choice ${index + 1} must have a bounding box`
            ).not.toBeNull();

            expect(
              box!.height,
              `choice ${index + 1} must meet >=56px touch height`
            ).toBeGreaterThanOrEqual(
              56
            );

            expect(
              box!.width,
              `choice ${index + 1} must meet >=56px touch width`
            ).toBeGreaterThanOrEqual(
              56
            );
          }

          await expect(
            page.locator(
              'img[data-asset-id="hibiscus-red"]'
            ).first()
          ).toBeVisible();

          await expect(
            page.locator(
              'img[data-asset-id="hibiscus-yellow"]'
            )
          ).toBeVisible();

          await page.screenshot({
            path:
              `test-results/draft-review-${viewport.name}.png`,
            fullPage:
              true
          });
        }
      );
    }
  }
);
