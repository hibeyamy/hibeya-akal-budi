import { expect, test } from "@playwright/test";

const story =
  "http://127.0.0.1:6006/iframe.html?id=assets-production-visual-baseline--six-asset-audit&viewMode=story";

const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow",
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

const viewports = [
  { name: "mobile", width: 390, height: 844 },
  { name: "tablet", width: 768, height: 1024 },
  { name: "desktop", width: 1280, height: 900 }
];

for (const viewport of viewports) {
  test(`production asset baseline is healthy on ${viewport.name}`, async ({ page }) => {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    await page.goto(story, { waitUntil: "networkidle" });

    await expect(page.getByTestId("production-visual-baseline")).toBeVisible();

    for (const id of ids) {
      const card = page.locator(`[data-asset-card="${id}"]`);
      const image = page.locator(`img[data-production-asset="${id}"]`);

      await expect(card).toBeVisible();
      await expect(card).toHaveAttribute("data-status", "approved");
      await expect(card).toHaveAttribute("data-delivery-format", "webp");
      await expect(image).toBeVisible();

      const loaded = await image.evaluate((element: HTMLImageElement) => ({
        complete: element.complete,
        naturalWidth: element.naturalWidth,
        naturalHeight: element.naturalHeight,
        src: element.currentSrc || element.src
      }));

      expect(loaded.complete).toBe(true);
      expect(loaded.naturalWidth).toBeGreaterThan(0);
      expect(loaded.naturalHeight).toBeGreaterThan(0);
      expect(loaded.src).toContain(".webp");
    }

    await page.screenshot({
      path: `test-results/production-assets-${viewport.name}.png`,
      fullPage: true
    });
  });
}
