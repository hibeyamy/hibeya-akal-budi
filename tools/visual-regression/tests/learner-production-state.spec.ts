import { expect, test } from "@playwright/test";

const learnerBase = process.env.HIBEYA_LEARNER_URL ?? "http://127.0.0.1:4173";

test.describe("production learner activity state lifecycle", () => {
  test("state hooks expose the real lifecycle when an activity is reachable", async ({ page }) => {
    await page.goto(learnerBase, { waitUntil: "networkidle" });

    const player = page.getByTestId("activity-player");

    if ((await player.count()) === 0) {
      test.skip(true, "Learner activity is not directly reachable from the default production route without journey/session setup.");
    }

    await expect(player).toHaveAttribute("data-activity-state", "idle");

    const choices = page.getByTestId("learner-choice");
    await expect(choices.first()).toBeVisible();

    const count = await choices.count();
    expect(count).toBeGreaterThan(1);

    // We deliberately do not infer correctness from DOM metadata.
    // Exercise choices until the production mechanic emits an incorrect state.
    let sawIncorrect = false;

    for (let i = 0; i < count; i += 1) {
      await choices.nth(i).click();

      const feedback = page.getByTestId("learner-feedback");
      const state = await feedback.getAttribute("data-feedback-state");

      if (state === "incorrect") {
        sawIncorrect = true;
        await expect(player).toHaveAttribute("data-activity-state", "retry");
        await expect(feedback).toContainText("Cuba lagi.");
        break;
      }

      if (state === "correct") {
        // Correctness came from the production mechanic. Completion is therefore
        // the appropriate state to assert; do not fabricate a retry afterwards.
        await expect(player).toHaveAttribute("data-activity-state", "completed");
        await expect(page.getByTestId("learner-completion")).toBeVisible();
        return;
      }
    }

    expect(sawIncorrect).toBe(true);

    // Continue through the remaining enabled choices until the mechanic itself
    // emits the correct state.
    for (let i = 0; i < count; i += 1) {
      const choice = choices.nth(i);
      if (await choice.isDisabled()) continue;

      await choice.click();

      const feedback = page.getByTestId("learner-feedback");
      const state = await feedback.getAttribute("data-feedback-state");

      if (state === "correct") {
        await expect(player).toHaveAttribute("data-activity-state", "completed");
        await expect(page.getByTestId("learner-completion")).toBeVisible();
        await expect(page.getByTestId("learner-choice").first()).toBeDisabled();
        return;
      }
    }

    throw new Error("Production mechanic did not reach a correct/completed state.");
  });
});
