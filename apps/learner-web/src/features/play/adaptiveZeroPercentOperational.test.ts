import {
  afterEach,
  describe,
  expect,
  it,
  vi
} from "vitest";

import {
  getAdaptiveRolloutBucket
} from "../../journey/adaptiveActivationPolicy";

import {
  parseAdaptiveRuntimeConfig
} from "../../journey/adaptiveRuntimeConfig";


function installTelemetryCapture() {
  const events:
    Array<{
      type:
        string;

      detail:
        Record<
          string,
          unknown
        >;
    }> = [];

  const originalWindow =
    globalThis.window;

  const originalCustomEvent =
    (
      globalThis as any
    ).CustomEvent;

  class TestCustomEvent {
    type:
      string;

    detail:
      Record<
        string,
        unknown
      >;

    constructor(
      type:
        string,
      init:
        {
          detail:
            Record<
              string,
              unknown
            >;
        }
    ) {
      this.type =
        type;

      this.detail =
        init.detail;
    }
  }

  Object.defineProperty(
    globalThis,
    "CustomEvent",
    {
      configurable:
        true,
      value:
        TestCustomEvent
    }
  );

  Object.defineProperty(
    globalThis,
    "window",
    {
      configurable:
        true,
      value: {
        dispatchEvent:
          (
            event:
              {
                type:
                  string;

                detail:
                  Record<
                    string,
                    unknown
                  >;
              }
          ) => {
            events.push(
              event
            );

            return true;
          }
      }
    }
  );

  return {
    events,

    restore:
      () => {
        if(
          typeof originalWindow ===
            "undefined"
        ){
          delete (
            globalThis as any
          ).window;
        }else{
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

        if(
          typeof originalCustomEvent ===
            "undefined"
        ){
          delete (
            globalThis as any
          ).CustomEvent;
        }else{
          Object.defineProperty(
            globalThis,
            "CustomEvent",
            {
              configurable:
                true,
              value:
                originalCustomEvent
            }
          );
        }
      }
  };
}


const baseInput = {
  childId:
    "child-zero-percent",
  ageBand:
    "3-4" as const,
  completedActivityIds:
    [],
  lastCompletedActivityId:
    null,
  masteredSkillIds:
    [],
  skillProgress:
    []
};


describe(
  "adaptive 0 percent operational verification",
  () => {
    afterEach(
      () => {
        vi.unstubAllEnvs();
        vi.resetModules();
      }
    );


    it(
      "parses enabled=true rollout=0 without granting adaptive authority",
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


    it(
      "keeps the real shared selector on legacy authority at enabled=true rollout=0",
      async () => {
        vi.stubEnv(
          "VITE_HIBEYA_ADAPTIVE_ENABLED",
          "true"
        );

        vi.stubEnv(
          "VITE_HIBEYA_ADAPTIVE_ROLLOUT_PERCENT",
          "0"
        );

        const capture =
          installTelemetryCapture();

        try {
          const {
            selectLearnerActivity
          } =
            await import(
              "./selectLearnerActivity"
            );

          const selected =
            selectLearnerActivity(
              baseInput
            );

          expect(
            selected
          ).not.toBeNull();

          expect(
            capture.events
          ).toHaveLength(
            1
          );

          const event =
            capture.events[0];

          expect(
            event.type
          ).toBe(
            "hibeya:adaptive-decision"
          );

          expect(
            event.detail.authority
          ).toBe(
            "legacy"
          );

          expect(
            event.detail.rolloutPercent
          ).toBe(
            0
          );

          /*
           * Current controlled-policy semantics collapse enabled=true/0%
           * into the same legacy fail-safe branch labelled "disabled".
           */
          expect(
            event.detail.fallbackReason
          ).toBe(
            "disabled"
          );

          expect(
            event.detail.selectedActivityId
          ).toBe(
            selected?.id
          );

          expect(
            "childId" in
              event.detail
          ).toBe(
            false
          );

          expect(
            "learnerKey" in
              event.detail
          ).toBe(
            false
          );

          expect(
            "deviceId" in
              event.detail
          ).toBe(
            false
          );
        } finally {
          capture.restore();
        }
      }
    );


    it(
      "assigns the same childId to the same cohort bucket across repeated calls",
      () => {
        const first =
          getAdaptiveRolloutBucket(
            "child-zero-percent"
          );

        const second =
          getAdaptiveRolloutBucket(
            "child-zero-percent"
          );

        expect(
          first
        ).toBe(
          second
        );

        expect(
          first
        ).toBeGreaterThanOrEqual(
          0
        );

        expect(
          first
        ).toBeLessThan(
          100
        );
      }
    );


    it(
      "produces deterministic but non-degenerate bucket distribution across learner ids",
      () => {
        const keys =
          Array.from(
            {
              length:
                32
            },
            (
              _,
              index
            ) =>
              `child-${index}`
          );

        const first =
          keys.map(
            key =>
              getAdaptiveRolloutBucket(
                key
              )
          );

        const second =
          keys.map(
            key =>
              getAdaptiveRolloutBucket(
                key
              )
          );

        expect(
          second
        ).toEqual(
          first
        );

        expect(
          new Set(
            first
          ).size
        ).toBeGreaterThan(
          1
        );
      }
    );


    it(
      "switches immediately back to explicit enabled=false legacy mode",
      async () => {
        vi.stubEnv(
          "VITE_HIBEYA_ADAPTIVE_ENABLED",
          "false"
        );

        vi.stubEnv(
          "VITE_HIBEYA_ADAPTIVE_ROLLOUT_PERCENT",
          "0"
        );

        const capture =
          installTelemetryCapture();

        try {
          const {
            selectLearnerActivity
          } =
            await import(
              "./selectLearnerActivity"
            );

          const selected =
            selectLearnerActivity(
              baseInput
            );

          expect(
            selected
          ).not.toBeNull();

          expect(
            capture.events
          ).toHaveLength(
            1
          );

          expect(
            capture.events[0]
              .detail
              .authority
          ).toBe(
            "legacy"
          );

          expect(
            capture.events[0]
              .detail
              .fallbackReason
          ).toBe(
            "disabled"
          );
        } finally {
          capture.restore();
        }
      }
    );


    it(
      "keeps shared-boundary selection equivalent for the same learner state",
      async () => {
        vi.stubEnv(
          "VITE_HIBEYA_ADAPTIVE_ENABLED",
          "true"
        );

        vi.stubEnv(
          "VITE_HIBEYA_ADAPTIVE_ROLLOUT_PERCENT",
          "0"
        );

        const capture =
          installTelemetryCapture();

        try {
          const {
            selectLearnerActivity
          } =
            await import(
              "./selectLearnerActivity"
            );

          const first =
            selectLearnerActivity(
              baseInput
            );

          const second =
            selectLearnerActivity(
              {
                ...baseInput
              }
            );

          expect(
            second?.id
          ).toBe(
            first?.id
          );
        } finally {
          capture.restore();
        }
      }
    );
  }
);
