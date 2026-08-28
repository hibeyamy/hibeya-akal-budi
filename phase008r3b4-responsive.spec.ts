import fs from "node:fs";
import path from "node:path";
import { expect, test, type Page } from "@playwright/test";

type StorybookEntry = {
  id?: string;
  title?: string;
  name?: string;
  type?: string;
  importPath?: string;
};

function resolveJourneyStoryId() {
  const indexFile = path.resolve(
    process.cwd(),
    "apps",
    "ui-storybook",
    "storybook-static",
    "index.json"
  );

  const index = JSON.parse(fs.readFileSync(indexFile, "utf8")) as {
    entries?: Record<string, StorybookEntry>;
  };

  const candidates = Object.values(index.entries ?? {}).filter(
    entry =>
      entry.title === "Learner/Journey" ||
      String(entry.importPath ?? "").includes("LearnerJourney.stories")
  );

  const target =
    candidates.find(entry => entry.type === "story" && entry.name === "Default") ??
    candidates.find(entry => entry.type === "story");

  if (!target?.id) {
    throw new Error(`Learner/Journey story not found. Candidates: ${JSON.stringify(candidates)}`);
  }
  return target.id;
}

const storyId = resolveJourneyStoryId();

async function openRealActivity(page: Page) {
  const response = await page.goto(
    `/iframe.html?id=${encodeURIComponent(storyId)}&viewMode=story`,
    { waitUntil: "networkidle" }
  );
  expect(response?.ok()).toBeTruthy();

  await expect(page.getByRole("button", { name: "Sambung belajar" })).toBeVisible();
  await page.getByRole("button", { name: "Lihat aktiviti" }).click();
  await page.getByRole("button", { name: /Kenal warna merah/ }).click();

  const player = page.getByTestId("activity-player");
  await expect(player).toBeVisible();
  await expect(player).toHaveAttribute("data-activity-state", "idle");
  return player;
}

async function assertNoHorizontalOverflow(page: Page) {
  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth + 1);
}

async function assertChoiceGeometry(page: Page) {
  const choices = page.getByTestId("learner-choice");
  const count = await choices.count();
  expect(count).toBeGreaterThan(1);

  for (let i = 0; i < count; i += 1) {
    const choice = choices.nth(i);
    const rect = await choice.boundingBox();
    expect(rect).not.toBeNull();
    expect(rect!.height).toBeGreaterThanOrEqual(56);
    expect(rect!.width).toBeGreaterThanOrEqual(56);

    const image = choice.locator("img[data-production-asset]");
    if ((await image.count()) > 0) {
      const loaded = await image.evaluate((element: HTMLImageElement) => ({
        complete: element.complete,
        naturalWidth: element.naturalWidth,
        naturalHeight: element.naturalHeight,
        image: element.getBoundingClientRect().toJSON(),
        container: element.parentElement?.getBoundingClientRect().toJSON()
      }));
      expect(loaded.complete).toBe(true);
      expect(loaded.naturalWidth).toBeGreaterThan(0);
      expect(loaded.naturalHeight).toBeGreaterThan(0);
      if (loaded.container) {
        expect(loaded.image.width).toBeLessThanOrEqual(loaded.container.width + 1);
        expect(loaded.image.height).toBeLessThanOrEqual(loaded.container.height + 1);
      }
    }
  }
}

async function exerciseProductionMechanic(page: Page) {
  const player = page.getByTestId("activity-player");
  const choices = page.getByTestId("learner-choice");
  const count = await choices.count();
  let sawIncorrect = false;

  for (let i = 0; i < count; i += 1) {
    const choice = choices.nth(i);
    if (await choice.isDisabled()) continue;
    await choice.click();

    const feedback = page.getByTestId("learner-feedback");
    const state = await feedback.getAttribute("data-feedback-state");

    if (state === "incorrect") {
      sawIncorrect = true;
      await expect(player).toHaveAttribute("data-activity-state", "retry");
      await expect(feedback).toContainText("Cuba lagi.");
      break;
    }
    if (state === "correct") {
      await expect(player).toHaveAttribute("data-activity-state", "completed");
      await expect(page.getByTestId("learner-completion")).toBeVisible();
      return;
    }
  }

  expect(sawIncorrect).toBe(true);

  for (let i = 0; i < count; i += 1) {
    const choice = choices.nth(i);
    if (await choice.isDisabled()) continue;
    await choice.click();

    if ((await page.getByTestId("learner-feedback").getAttribute("data-feedback-state")) === "correct") {
      await expect(player).toHaveAttribute("data-activity-state", "completed");
      await expect(page.getByTestId("learner-completion")).toBeVisible();
      await expect(choices.first()).toBeDisabled();
      return;
    }
  }

  throw new Error("Production mechanic did not reach correct/completed state.");
}

for (const viewport of [
  { name: "mobile", width: 390, height: 844 },
  { name: "tablet", width: 768, height: 1024 },
  { name: "desktop", width: 1280, height: 900 }
]) {
  test(`learner production activity is responsive on ${viewport.name}`, async ({ page }) => {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    await openRealActivity(page);

    await assertNoHorizontalOverflow(page);
    await assertChoiceGeometry(page);
    await exerciseProductionMechanic(page);
    await assertNoHorizontalOverflow(page);

    await page.getByTestId("learner-completion").scrollIntoViewIfNeeded();
    await expect(page.getByTestId("learner-completion")).toBeVisible();

    await page.screenshot({
      path: `test-results/learner-r3b4-${viewport.name}.png`,
      fullPage: true
    });
  });
}
