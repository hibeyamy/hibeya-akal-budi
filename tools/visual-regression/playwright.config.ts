import {
  defineConfig,
  devices
} from "@playwright/test";

export default defineConfig({
  testDir:
    "./tests",

  timeout:
    30_000,

  expect: {
    timeout:
      5_000,

    toHaveScreenshot: {
      animations:
        "disabled",

      caret:
        "hide",

      scale:
        "css",

      maxDiffPixelRatio:
        0.01
    }
  },

  fullyParallel:
    false,

  workers:
    1,

  retries:
    0,

  reporter: [
    ["list"],
    [
      "html",
      {
        outputFolder:
          "playwright-report",

        open:
          "never"
      }
    ]
  ],

  use: {
    baseURL:
      "http://127.0.0.1:6106",

    viewport: {
      width:
        1280,

      height:
        900
    },

    deviceScaleFactor:
      1,

    colorScheme:
      "light",

    reducedMotion:
      "reduce",

    locale:
      "ms-MY",

    timezoneId:
      "Asia/Kuala_Lumpur",

    screenshot:
      "only-on-failure",

    trace:
      "retain-on-failure"
  },

  projects: [
    {
      name:
        "chromium",

      use: {
        ...devices[
          "Desktop Chrome"
        ]
      }
    }
  ],

  webServer: {
    command:
      "node serve-storybook.mjs",

    url:
      "http://127.0.0.1:6106",

    reuseExistingServer:
      false,

    timeout:
      30_000
  }
});
