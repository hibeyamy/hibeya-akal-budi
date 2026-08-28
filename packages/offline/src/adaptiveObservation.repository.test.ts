import {
  beforeEach,
  describe,
  expect,
  it,
  vi
} from "vitest";

type RecordValue = {
  eventId: string;
  occurredAt: number;
  authority: "legacy" | "adaptive";
  fallbackReason: string;
  rolloutBucket: number;
  rolloutPercent: number;
  legacyActivityId: string;
  adaptiveActivityId: string | null;
  selectedActivityId: string;
  syncStatus: "pending" | "synced" | "failed";
  createdAt: number;
  updatedAt: number;
};

const records =
  new Map<
    string,
    RecordValue
  >();

const database = {
  async put(
    _store:
      string,
    value:
      RecordValue
  ) {
    records.set(
      value.eventId,
      structuredClone(
        value
      )
    );

    return value.eventId;
  },

  async get(
    _store:
      string,
    eventId:
      string
  ) {
    const value =
      records.get(
        eventId
      );

    return value
      ? structuredClone(
          value
        )
      : undefined;
  },

  async getAllFromIndex(
    _store:
      string,
    _index:
      string,
    status:
      string
  ) {
    return [
      ...records.values()
    ]
      .filter(
        value =>
          value.syncStatus ===
          status
      )
      .map(
        value =>
          structuredClone(
            value
          )
      );
  }
};


vi.mock(
  "./database",
  async importOriginal => {
    const actual =
      await importOriginal<
        typeof import(
          "./database"
        )
      >();

    return {
      ...actual,

      getDatabase:
        vi.fn(
          async () =>
            database
        )
    };
  }
);


import {
  getAdaptiveObservation,
  getPendingAdaptiveObservations,
  markAdaptiveObservationSynced,
  queueAdaptiveObservation
} from "./adaptiveObservation.repository";


describe(
  "adaptive observation repository",
  () => {
    beforeEach(
      () => {
        records.clear();
      }
    );


    it(
      "queues a privacy-safe pending observation and reuses eventId idempotently",
      async () => {
        const input = {
          eventId:
            "00000000-0000-4000-8000-000000000001",

          occurredAt:
            1_700_000_000_000,

          authority:
            "legacy" as const,

          fallbackReason:
            "disabled" as const,

          rolloutBucket:
            17,

          rolloutPercent:
            0,

          legacyActivityId:
            "legacy-a",

          adaptiveActivityId:
            null,

          selectedActivityId:
            "legacy-a"
        };

        await queueAdaptiveObservation(
          input
        );

        await queueAdaptiveObservation(
          input
        );

        const pending =
          await getPendingAdaptiveObservations();

        expect(
          pending
        ).toHaveLength(
          1
        );

        expect(
          pending[0].eventId
        ).toBe(
          input.eventId
        );

        expect(
          "childId" in
            pending[0]
        ).toBe(
          false
        );

        expect(
          "deviceId" in
            pending[0]
        ).toBe(
          false
        );

        expect(
          "deviceToken" in
            pending[0]
        ).toBe(
          false
        );
      }
    );


    it(
      "marks successful observations synced",
      async () => {
        const observation =
          await queueAdaptiveObservation({
            eventId:
              "00000000-0000-4000-8000-000000000002",

            occurredAt:
              1_700_000_000_001,

            authority:
              "adaptive",

            fallbackReason:
              "adaptive-selected",

            rolloutBucket:
              0,

            rolloutPercent:
              1,

            legacyActivityId:
              "legacy-a",

            adaptiveActivityId:
              "adaptive-b",

            selectedActivityId:
              "adaptive-b"
          });

        await markAdaptiveObservationSynced(
          observation.eventId
        );

        expect(
          (
            await getAdaptiveObservation(
              observation.eventId
            )
          )?.syncStatus
        ).toBe(
          "synced"
        );

        expect(
          await getPendingAdaptiveObservations()
        ).toHaveLength(
          0
        );
      }
    );
  }
);
