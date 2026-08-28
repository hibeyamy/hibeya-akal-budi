import fs from "node:fs";
import path from "node:path";
import { expect, test, type Locator, type Page } from "@playwright/test";

type StorybookEntry = {
  id?: string;
  title?: string;
  name?: string;
  type?: string;
  importPath?: string;
};

function resolveJourneyStoryId() {
  const indexFile = path.resolve(process.cwd(), "apps", "ui-storybook", "storybook-static", "index.json");
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
  await expect(player).toHaveAttribute("data-answer-count", "0");
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

/*
 * Synchronise on the production answer counter before inspecting feedback.
 * Reading data-feedback-state immediately after click can observe the previous
 * React render (idle or the prior incorrect feedback).
 */
async function submitAndWaitForCommit(
  player: Locator,
  choice: Locator
): Promise<"correct" | "incorrect"> {
  const beforeRaw = await player.getAttribute("data-answer-count");
  const before = Number(beforeRaw ?? "0");
  expect(Number.isFinite(before)).toBe(true);

  await choice.click();

  await expect(player).toHaveAttribute("data-answer-count", String(before + 1));

  const feedback = player.page().getByTestId("learner-feedback");
  await expect
    .poll(async () => feedback.getAttribute("data-feedback-state"))
    .toMatch(/^(correct|incorrect)$/);

  const state = await feedback.getAttribute("data-feedback-state");
  if (state !== "correct" && state !== "incorrect") {
    throw new Error(`Unexpected committed feedback state: ${String(state)}`);
  }
  return state;
}

async function reachRetryThroughProductionMechanic(page: Page) {
  let candidate = 0;

  while (true) {
    const player = await openRealActivity(page);
    const choices = page.getByTestId("learner-choice");
    const count = await choices.count();

    if (candidate >= count) {
      throw new Error("Production mechanic did not expose an incorrect option.");
    }

    const state = await submitAndWaitForCommit(player, choices.nth(candidate));

    if (state === "incorrect") {
      await expect(player).toHaveAttribute("data-activity-state", "retry");
      await expect(page.getByTestId("learner-feedback")).toContainText("Cuba lagi.");
      return;
    }

    await expect(player).toHaveAttribute("data-activity-state", "completed");
    await expect(page.getByTestId("learner-completion")).toBeVisible();
    candidate += 1;
  }
}

async function completeFromRetry(page: Page) {
  const player = page.getByTestId("activity-player");
  const choices = page.getByTestId("learner-choice");
  const count = await choices.count();

  for (let i = 0; i < count; i += 1) {
    const choice = choices.nth(i);
    if (await choice.isDisabled()) continue;

    const state = await submitAndWaitForCommit(player, choice);

    if (state === "correct") {
      await expect(player).toHaveAttribute("data-activity-state", "completed");
      await expect(page.getByTestId("learner-completion")).toBeVisible();
      await expect(choices.first()).toBeDisabled();
      return;
    }

    await expect(player).toHaveAttribute("data-activity-state", "retry");
  }

  throw new Error("Production mechanic did not reach correct/completed state from retry.");
}

for (const viewport of [
  { name: "mobile", width: 390, height: 844 },
  { name: "tablet", width: 768, height: 1024 },
  { name: "desktop", width: 1280, height: 900 }
]) {
  test(`learner production activity is responsive on ${viewport.name}`, async ({ page }) => {
    test.setTimeout(60_000);
    await page.setViewportSize({ width: viewport.width, height: viewport.height });

    await openRealActivity(page);
    await assertNoHorizontalOverflow(page);
    await assertChoiceGeometry(page);

    await reachRetryThroughProductionMechanic(page);
    await assertNoHorizontalOverflow(page);

    await completeFromRetry(page);
    await assertNoHorizontalOverflow(page);

    await page.getByTestId("learner-completion").scrollIntoViewIfNeeded();
    await expect(page.getByTestId("learner-completion")).toBeVisible();

    await page.screenshot({
      path: `test-results/learner-r3b4-${viewport.name}.png`,
      fullPage: true
    });
  });
}
