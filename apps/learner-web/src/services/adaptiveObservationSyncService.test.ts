import {
  describe,
  expect,
  it,
  vi
} from "vitest";


vi.mock(
  "@akal-budi/offline",
  () => ({
    getLearnerDevice:
      vi.fn(
        async () => ({
          id:
            "active-device",
          deviceId:
            "00000000-0000-4000-8000-000000000010",
          childId:
            "00000000-0000-4000-8000-000000000011",
          deviceToken:
            "secret-device-token",
          deviceName:
            null,
          activatedAt:
            1
        })
      ),

    getNetworkStatus:
      vi.fn(
        () => ({
          online:
            true
        })
      ),

    processPendingAdaptiveObservations:
      vi.fn(
        async () => ({
          attempted:
            0,
          succeeded:
            0,
          failed:
            0
        })
      ),

    queueAdaptiveObservation:
      vi.fn(
        async () => ({
          eventId:
            "event"
        })
      )
  })
);


const rpc =
  vi.fn(
    async () => ({
      error:
        null
    })
  );


vi.mock(
  "../lib/supabase",
  () => ({
    supabase: {
      rpc
    }
  })
);


describe(
  "adaptive observation sync service",
  () => {
    it(
      "uses device credentials only as RPC authentication parameters",
      async () => {
        const {
          syncStoredAdaptiveObservation
        } =
          await import(
            "./adaptiveObservationSyncService"
          );

        await syncStoredAdaptiveObservation({
          eventId:
            "00000000-0000-4000-8000-000000000012",
          occurredAt:
            1_700_000_000_000,
          authority:
            "legacy",
          fallbackReason:
            "disabled",
          rolloutBucket:
            9,
          rolloutPercent:
            0,
          legacyActivityId:
            "legacy-a",
          adaptiveActivityId:
            null,
          selectedActivityId:
            "legacy-a",
          syncStatus:
            "pending",
          createdAt:
            1,
          updatedAt:
            1
        });

        expect(
          rpc
        ).toHaveBeenCalledTimes(
          1
        );

        const [
          name,
          args
        ] =
          rpc.mock.calls[0];

        expect(
          name
        ).toBe(
          "ingest_adaptive_observation"
        );

        expect(
          args.p_device_id
        ).toBeTruthy();

        expect(
          args.p_device_token
        ).toBeTruthy();

        expect(
          "p_child_id" in
            args
        ).toBe(
          false
        );

        expect(
          "p_learner_key" in
            args
        ).toBe(
          false
        );
      }
    );
  }
);
