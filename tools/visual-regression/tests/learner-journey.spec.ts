import fs from "node:fs";
import path from "node:path";

import {
  expect,
  test,
  type Page
} from "@playwright/test";

type StorybookEntry = {
  id?: string;
  title?: string;
  name?: string;
  type?: string;
  importPath?: string;
};

function resolveJourneyStoryId() {
  const indexFile =
    path.resolve(
      process.cwd(),
      "apps",
      "ui-storybook",
      "storybook-static",
      "index.json"
    );

  const index =
    JSON.parse(
      fs.readFileSync(
        indexFile,
        "utf8"
      )
    ) as {
      entries?: Record<
        string,
        StorybookEntry
      >;
    };

  const entries =
    Object.values(
      index.entries ??
      {}
    );

  const candidates =
    entries.filter(
      entry =>
        entry.title ===
          "Learner/Journey" ||
        String(
          entry.importPath ??
          ""
        ).includes(
          "LearnerJourney.stories"
        )
    );

  const target =
    candidates.find(
      entry =>
        entry.type ===
          "story" &&
        entry.name ===
          "Default"
    ) ??
    candidates.find(
      entry =>
        entry.type ===
        "story"
    );

  if (!target?.id) {
    throw new Error(
      `Learner/Journey story not found. Candidates: ${JSON.stringify(candidates)}`
    );
  }

  return target.id;
}

const journeyStoryId =
  resolveJourneyStoryId();

async function openJourney(
  page:
    Page
) {
  const runtimeErrors:
    string[] = [];

  page.on(
    "pageerror",
    error => {
      runtimeErrors.push(
        `PAGE ERROR: ${error.message}`
      );
    }
  );

  page.on(
    "console",
    message => {
      if (
        message.type() ===
          "error"
      ) {
        runtimeErrors.push(
          `CONSOLE ERROR: ${message.text()}`
        );
      }
    }
  );

  const response =
    await page.goto(
      `/iframe.html?id=${encodeURIComponent(journeyStoryId)}&viewMode=story`,
      {
        waitUntil:
          "networkidle"
      }
    );

  expect(
    response?.ok(),
    `Storybook iframe HTTP failure for ${journeyStoryId}`
  ).toBeTruthy();

  const homeButton =
    page.getByRole(
      "button",
      {
        name:
          "Sambung belajar"
      }
    );

  try {
    await expect(
      homeButton
    ).toBeVisible({
      timeout:
        10_000
    });
  }
  catch {
    const bodyText =
      await page.locator(
        "body"
      ).innerText()
        .catch(
          () =>
            "<body unavailable>"
        );

    throw new Error(
      [
        `Learner journey story failed to render.`,
        `Resolved Storybook ID: ${journeyStoryId}`,
        `URL: ${page.url()}`,
        `Runtime errors:`,
        runtimeErrors.length
          ? runtimeErrors.join("\n")
          : "<none captured>",
        `Body:`,
        bodyText.slice(
          0,
          4000
        )
      ].join(
        "\n"
      )
    );
  }
}

test.describe(
  "learner journey",
  () => {
    test(
      "home opens explore and returns home",
      async ({
        page
      }) => {
        await openJourney(
          page
        );

        await expect(
          page.getByRole(
            "heading",
            {
              name:
                "Warna di sekeliling kita"
            }
          )
        ).toBeVisible();

        await page.getByRole(
          "button",
          {
            name:
              "Lihat aktiviti"
          }
        ).click();

        await expect(
          page.getByRole(
            "heading",
            {
              name:
                "Pilih aktiviti"
            }
          )
        ).toBeVisible();

        await page.getByRole(
          "button",
          {
            name:
              "Kembali"
          }
        ).click();

        await expect(
          page.getByRole(
            "button",
            {
              name:
                "Sambung belajar"
            }
          )
        ).toBeVisible();
      }
    );

    test(
      "explore opens the requested red activity through the typed adapter",
      async ({
        page
      }) => {
        await openJourney(
          page
        );

        await page.getByRole(
          "button",
          {
            name:
              "Lihat aktiviti"
          }
        ).click();

        await page.getByRole(
          "button",
          {
            name:
              /Kenal warna merah/
          }
        ).click();

        await expect(
          page.getByRole(
            "button",
            {
              name:
                "Keluar aktiviti"
            }
          )
        ).toBeVisible();
      }
    );

    test(
      "exit returns to the view that launched the activity",
      async ({
        page
      }) => {
        await openJourney(
          page
        );

        await page.getByRole(
          "button",
          {
            name:
              "Lihat aktiviti"
          }
        ).click();

        await page.getByRole(
          "button",
          {
            name:
              /Warna bunga raya/
          }
        ).click();

        await expect(
          page.getByRole(
            "button",
            {
              name:
                "Keluar aktiviti"
            }
          )
        ).toBeVisible();

        await page.getByRole(
          "button",
          {
            name:
              "Keluar aktiviti"
          }
        ).click();

        await expect(
          page.getByRole(
            "heading",
            {
              name:
                "Pilih aktiviti"
            }
          )
        ).toBeVisible();
      }
    );

    test(
      "home continue opens an activity and exit returns home",
      async ({
        page
      }) => {
        await openJourney(
          page
        );

        await page.getByRole(
          "button",
          {
            name:
              "Sambung belajar"
          }
        ).click();

        await expect(
          page.getByRole(
            "button",
            {
              name:
                "Keluar aktiviti"
            }
          )
        ).toBeVisible();

        await page.getByRole(
          "button",
          {
            name:
              "Keluar aktiviti"
          }
        ).click();

        await expect(
          page.getByRole(
            "button",
            {
              name:
                "Sambung belajar"
            }
          )
        ).toBeVisible();
      }
    );

    test(
      "journey controls meet the preferred learner touch target",
      async ({
        page
      }) => {
        await openJourney(
          page
        );

        for (
          const name
          of [
            "Sambung belajar",
            "Lihat aktiviti"
          ]
        ) {
          const button =
            page.getByRole(
              "button",
              {
                name
              }
            );

          await expect(
            button
          ).toBeVisible();

          const dimensions =
            await button.evaluate(
              element => {
                const rect =
                  element
                    .getBoundingClientRect();

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
      }
    );
  }
);


test("R3B.8 browser persistence recovery", async ({ page }) => {
  await openJourney(page);

  await page.getByRole(
    "button",
    {
      name:
        "Sambung belajar"
    }
  ).click();

  await expect(
    page.getByRole(
      "button",
      {
        name:
          "Keluar aktiviti"
      }
    )
  ).toBeVisible();

  const player =
    page.getByTestId(
      "activity-player"
    );

  await expect(
    player
  ).toBeVisible();

  const activityId =
    await player.getAttribute(
      "data-activity-id"
    );

  expect(
    activityId
  ).toBeTruthy();

  const now =
    Date.now();

  // Entering the activity creates a real incomplete session.
  // Remove that setup session before inserting the deterministic
  // recovery fixture; otherwise "Mula semula" correctly deletes
  // the newer automatic session while our older seed remains.
  await page.evaluate(
    async () => {
      await new Promise<void>(
        (
          resolve,
          reject
        ) => {
          const request =
            indexedDB.open("hibeya-akal-budi", 4);

          request.onerror =
            () =>
              reject(
                request.error
              );

          request.onsuccess =
            () => {
              const database =
                request.result;

              const transaction =
                database.transaction(
                  "sessions",
                  "readwrite"
                );

              const clearRequest =
                transaction
                  .objectStore(
                    "sessions"
                  )
                  .clear();

              clearRequest.onerror =
                () =>
                  reject(
                    clearRequest.error
                  );

              transaction.oncomplete =
                () => {
                  database.close();
                  resolve();
                };

              transaction.onerror =
                () =>
                  reject(
                    transaction.error
                  );
            };
        }
      );
    }
  );

  await page.evaluate(
    async ({
      activityId,
      now
    }) => {
      if (!activityId) {
        throw new Error(
          "activityId missing before IndexedDB seed"
        );
      }

      await new Promise<void>(
        (
          resolve,
          reject
        ) => {
          const request =
            indexedDB.open("hibeya-akal-budi", 4);

          request.onerror =
            () =>
              reject(
                request.error
              );

          request.onsuccess =
            () => {
              const database =
                request.result;

              const transaction =
                database.transaction(
                  "sessions",
                  "readwrite"
                );

              transaction
                .objectStore(
                  "sessions"
                )
                .put({
                  id:
                    "r3b8-browser-recovery",

                  activityId,

                  activityVersion:
                    1,

                  startedAt:
                    now - 5000,

                  answers:
                    [],

                  syncStatus:
                    "pending",

                  createdAt:
                    now - 5000,

                  updatedAt:
                    now
                });

              transaction.oncomplete =
                () => {
                  database.close();
                  resolve();
                };

              transaction.onerror =
                () =>
                  reject(
                    transaction.error
                  );
            };
        }
      );
    },
    {
      activityId,
      now
    }
  );

  await page.reload({
    waitUntil:
      "networkidle"
  });

  await expect(
    page.getByRole(
      "button",
      {
        name:
          "Sambung belajar"
      }
    )
  ).toBeVisible();

  await page.getByRole(
    "button",
    {
      name:
        "Sambung belajar"
    }
  ).click();

  await expect(
    page.getByText(
      "Aktiviti sebelumnya belum selesai."
    )
  ).toBeVisible();

  await expect(
    page.getByRole(
      "button",
      {
        name:
          "Sambung"
      }
    )
  ).toBeVisible();

  await expect(
    page.getByRole(
      "button",
      {
        name:
          "Mula semula"
      }
    )
  ).toBeVisible();

  await page.getByRole(
    "button",
    {
      name:
        "Mula semula"
    }
  ).click();

  await expect(
    page.getByText(
      "Aktiviti sebelumnya belum selesai."
    )
  ).toHaveCount(
    0
  );

  // The UI transition can complete before the IndexedDB mutation has
  // become observable to a separate transaction. Assert the durable
  // state eventually rather than racing the click handler.
  await expect
    .poll(
      async () =>
        page.evaluate(
          async () =>
            new Promise<boolean>(
              (
                resolve,
                reject
              ) => {
                const request =
                  indexedDB.open("hibeya-akal-budi", 4);

                request.onerror =
                  () =>
                    reject(
                      request.error
                    );

                request.onsuccess =
                  () => {
                    const database =
                      request.result;

                    const transaction =
                      database.transaction(
                        "sessions",
                        "readonly"
                      );

                    const getRequest =
                      transaction
                        .objectStore(
                          "sessions"
                        )
                        .get(
                          "r3b8-browser-recovery"
                        );

                    getRequest.onsuccess =
                      () => {
                        const value =
                          getRequest.result;

                        database.close();

                        resolve(
                          value ===
                            undefined
                        );
                      };

                    getRequest.onerror =
                      () =>
                        reject(
                          getRequest.error
                        );
                  };
              }
            )
        ),
      {
        message:
          "restarted recovery session should be durably removed from IndexedDB",
        timeout:
          5000,
        intervals:
          [
            100,
            250,
            500
          ]
      }
    )
    .toBe(
      true
    );
});
