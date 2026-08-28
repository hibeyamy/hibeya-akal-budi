import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

type Entry = { id?: string; title?: string; name?: string; type?: string; importPath?: string };

function resolveStoryId() {
  const indexPath = path.resolve(process.cwd(), "apps", "ui-storybook", "storybook-static", "index.json");
  const index = JSON.parse(fs.readFileSync(indexPath, "utf8")) as { entries?: Record<string, Entry> };
  const candidates = Object.values(index.entries ?? {}).filter(
    e => e.title === "Learner/Journey" || String(e.importPath ?? "").includes("LearnerJourney.stories")
  );
  const target =
    candidates.find(e => e.type === "story" && e.name === "Default") ??
    candidates.find(e => e.type === "story");
  if (!target?.id) throw new Error("Learner/Journey story not found");
  return target.id;
}

const storyId = resolveStoryId();

async function openActivity(page: Page) {
  await page.goto(`/iframe.html?id=${encodeURIComponent(storyId)}&viewMode=story`, {
    waitUntil: "networkidle"
  });
  await page.getByRole("button", { name: "Lihat aktiviti" }).click();
  await page.getByRole("button", { name: /Kenal warna merah/ }).click();
  await expect(page.getByTestId("activity-player")).toHaveAttribute("data-activity-state", "idle");
}

test("learner activity satisfies automated accessibility baseline", async ({ page }) => {
  await openActivity(page);
  const result = await new AxeBuilder({ page })
    .include('[data-testid="activity-player"]')
    .analyze();
  expect(result.violations, JSON.stringify(result.violations, null, 2)).toEqual([]);
});

test("keyboard focus, activation and feedback live region are valid", async ({ page }) => {
  await openActivity(page);

  const feedback = page.getByTestId("learner-feedback");
  await expect(feedback).toHaveAttribute("aria-live", "polite");
  await expect(feedback).toHaveAttribute("aria-atomic", "true");

  const firstChoice = page.getByTestId("learner-choice").first();

  for (let i = 0; i < 20; i += 1) {
    await page.keyboard.press("Tab");
    if (await firstChoice.evaluate(el => document.activeElement === el)) break;
  }

  await expect(firstChoice).toBeFocused();

  const focusVisible = await firstChoice.evaluate(el => {
    const style = getComputedStyle(el);
    const outlineWidth = Number.parseFloat(style.outlineWidth) || 0;
    const hasShadow = style.boxShadow !== "none" && style.boxShadow !== "";
    return outlineWidth > 0 || hasShadow;
  });
  expect(focusVisible).toBe(true);

  await page.keyboard.press("Enter");
  await expect(page.getByTestId("activity-player")).toHaveAttribute("data-answer-count", "1");
  await expect
    .poll(() => feedback.getAttribute("data-feedback-state"))
    .toMatch(/^(correct|incorrect)$/);
  await expect(feedback).not.toHaveText("");
});

test("completion disables choices", async ({ page }) => {
  let candidate = 0;

  while (true) {
    await openActivity(page);
    const choices = page.getByTestId("learner-choice");
    const player = page.getByTestId("activity-player");

    if (candidate >= await choices.count()) throw new Error("No correct option exposed");

    await choices.nth(candidate).click();
    await expect(player).toHaveAttribute("data-answer-count", "1");
    await expect
      .poll(() => page.getByTestId("learner-feedback").getAttribute("data-feedback-state"))
      .toMatch(/^(correct|incorrect)$/);

    if (await player.getAttribute("data-activity-state") === "completed") {
      await expect(page.getByTestId("learner-completion")).toBeVisible();
      for (let i = 0; i < await choices.count(); i += 1) {
        await expect(choices.nth(i)).toBeDisabled();
      }
      return;
    }
    candidate += 1;
  }
});

test("learner choices effectively suppress transition under reduced motion", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await openActivity(page);

  const maxSeconds = await page.getByTestId("learner-choice").first().evaluate(el => {
    const durations = getComputedStyle(el).transitionDuration
      .split(",")
      .map(value => value.trim())
      .map(value => value.endsWith("ms") ? Number.parseFloat(value) / 1000 : Number.parseFloat(value));
    return Math.max(...durations);
  });

  expect(maxSeconds).toBeLessThanOrEqual(0.0001);
});
