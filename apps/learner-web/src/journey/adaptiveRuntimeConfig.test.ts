import {
  describe,
  expect,
  it
} from "vitest";

import {
  parseAdaptiveRuntimeConfig
} from "./adaptiveRuntimeConfig";


describe(
  "adaptive runtime config",
  () => {
    it(
      "fails closed when config is missing",
      () => {
        expect(
          parseAdaptiveRuntimeConfig(
            {}
          )
        ).toEqual({
          enabled:
            false,
          rolloutPercent:
            0
        });
      }
    );


    it(
      "fails closed when enabled is malformed",
      () => {
        expect(
          parseAdaptiveRuntimeConfig({
            VITE_HIBEYA_ADAPTIVE_ENABLED:
              "yes",
            VITE_HIBEYA_ADAPTIVE_ROLLOUT_PERCENT:
              "5"
          })
        ).toEqual({
          enabled:
            false,
          rolloutPercent:
            0
        });
      }
    );


    it(
      "fails closed when rollout is malformed or out of range",
      () => {
        for(
          const value
          of [
            "abc",
            "-1",
            "101"
          ]
        ){
          expect(
            parseAdaptiveRuntimeConfig({
              VITE_HIBEYA_ADAPTIVE_ENABLED:
                "true",
              VITE_HIBEYA_ADAPTIVE_ROLLOUT_PERCENT:
                value
            })
          ).toEqual({
            enabled:
              false,
            rolloutPercent:
              0
          });
        }
      }
    );


    it(
      "accepts explicit enabled plus bounded rollout",
      () => {
        expect(
          parseAdaptiveRuntimeConfig({
            VITE_HIBEYA_ADAPTIVE_ENABLED:
              "true",
            VITE_HIBEYA_ADAPTIVE_ROLLOUT_PERCENT:
              "5"
          })
        ).toEqual({
          enabled:
            true,
          rolloutPercent:
            5
        });
      }
    );


    it(
      "supports an explicit enabled 0 percent configuration",
      () => {
        expect(
          parseAdaptiveRuntimeConfig({
            VITE_HIBEYA_ADAPTIVE_ENABLED:
              "true",
            VITE_HIBEYA_ADAPTIVE_ROLLOUT_PERCENT:
              "0"
          })
        ).toEqual({
          enabled:
            true,
          rolloutPercent:
            0
        });
      }
    );
  }
);
