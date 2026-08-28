import {
  describe,
  expect,
  it,
  vi
} from "vitest";

import {
  emitAdaptiveDecisionTelemetry,
  toAdaptiveDecisionTelemetry
} from "./adaptiveDecisionTelemetry";


const decision =
  {
    activity: {
      id:
        "selected"
    },
    authority:
      "legacy",
    fallbackReason:
      "disabled",
    rolloutBucket:
      42,
    rolloutPercent:
      0,
    legacyActivityId:
      "legacy",
    adaptiveActivityId:
      null
  } as any;


describe(
  "adaptive decision telemetry",
  () => {
    it(
      "contains no learner identifier field",
      () => {
        const payload =
          toAdaptiveDecisionTelemetry(
            decision
          );

        expect(
          payload
        ).toEqual({
          authority:
            "legacy",
          fallbackReason:
            "disabled",
          rolloutBucket:
            42,
          rolloutPercent:
            0,
          legacyActivityId:
            "legacy",
          adaptiveActivityId:
            null,
          selectedActivityId:
            "selected"
        });

        expect(
          "childId" in
            payload
        ).toBe(
          false
        );

        expect(
          "learnerKey" in
            payload
        ).toBe(
          false
        );
      }
    );


    it(
      "never throws when telemetry dispatch fails",
      () => {
        const originalWindow =
          globalThis.window;

        const dispatchEvent =
          vi.fn(
            () => {
              throw new Error(
                "simulated telemetry failure"
              );
            }
          );

        Object.defineProperty(
          globalThis,
          "window",
          {
            configurable:
              true,
            value: {
              dispatchEvent
            }
          }
        );

        try {
          expect(
            () =>
              emitAdaptiveDecisionTelemetry(
                decision
              )
          ).not.toThrow();

          expect(
            dispatchEvent
          ).toHaveBeenCalledTimes(
            1
          );
        } finally {
          if (
            typeof originalWindow ===
              "undefined"
          ) {
            delete (
              globalThis as any
            ).window;
          } else {
            Object.defineProperty(
              globalThis,
              "window",
              {
                configurable:
                  true,
                value:
                  originalWindow
              }
            );
          }
        }
      }
    );
  }
);
