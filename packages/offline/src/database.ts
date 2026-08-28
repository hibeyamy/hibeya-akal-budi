import {
  openDB,
  type DBSchema,
  type IDBPDatabase
} from "idb";

import type {
  GameAnswer,
  GameSessionResult
} from "@akal-budi/game-runtime";

export type SyncStatus =
  | "pending"
  | "synced"
  | "failed";

export type AdaptiveObservationAuthority =
  | "legacy"
  | "adaptive";

export type AdaptiveObservationFallbackReason =
  | "disabled"
  | "outside-cohort"
  | "legacy-null"
  | "shadow-null"
  | "shadow-error"
  | "invalid-adaptive-candidate"
  | "adaptive-selected";

export interface StoredAdaptiveObservation {
  eventId: string;

  occurredAt: number;

  authority:
    AdaptiveObservationAuthority;

  fallbackReason:
    AdaptiveObservationFallbackReason;

  rolloutBucket: number;
  rolloutPercent: number;

  legacyActivityId: string;
  adaptiveActivityId: string | null;
  selectedActivityId: string;

  syncStatus: SyncStatus;

  createdAt: number;
  updatedAt: number;
}

export interface StoredSession {
  id: string;

  activityId: string;
  activityVersion: number;

  startedAt: number;
  completedAt?: number;

  answers: GameAnswer[];

  result?: GameSessionResult;

  syncStatus: SyncStatus;

  createdAt: number;
  updatedAt: number;
}

export interface LearnerDeviceIdentity {
  id: "active-device";

  deviceId: string;
  childId: string;

  deviceToken: string;

  deviceName: string | null;

  activatedAt: number;
}

export interface LocalSetting {
  key: string;

  value: unknown;
}

interface AkalBudiDatabase extends DBSchema {
  sessions: {
    key: string;
    value: StoredSession;

    indexes: {
      "by-sync-status": SyncStatus;
      "by-activity-id": string;
      "by-updated-at": number;
    };
  };

  learnerDevice: {
    key: "active-device";
    value: LearnerDeviceIdentity;
  };

  settings: {
    key: string;
    value: LocalSetting;
  };

  adaptiveObservations: {
    key: string;
    value: StoredAdaptiveObservation;

    indexes: {
      "by-sync-status": SyncStatus;
      "by-occurred-at": number;
    };
  };
}

const DATABASE_NAME =
  "hibeya-akal-budi";

const DATABASE_VERSION =
  4;

let databasePromise:
  | Promise<
      IDBPDatabase<AkalBudiDatabase>
    >
  | undefined;

export function getDatabase() {
  if (!databasePromise) {
    databasePromise =
      openDB<AkalBudiDatabase>(
        DATABASE_NAME,
        DATABASE_VERSION,
        {
          upgrade(
            database,
            oldVersion
          ) {
            if (
              oldVersion < 1
            ) {
              const sessionStore =
                database
                  .createObjectStore(
                    "sessions",
                    {
                      keyPath:
                        "id"
                    }
                  );

              sessionStore
                .createIndex(
                  "by-sync-status",
                  "syncStatus"
                );

              sessionStore
                .createIndex(
                  "by-activity-id",
                  "activityId"
                );

              sessionStore
                .createIndex(
                  "by-updated-at",
                  "updatedAt"
                );
            }

            if (
              oldVersion < 2
            ) {
              database
                .createObjectStore(
                  "learnerDevice",
                  {
                    keyPath:
                      "id"
                  }
                );
            }

            if (
              oldVersion < 3
            ) {
              database
                .createObjectStore(
                  "settings",
                  {
                    keyPath:
                      "key"
                  }
                );
            }

            if (
              oldVersion < 4
            ) {
              const observationStore =
                database
                  .createObjectStore(
                    "adaptiveObservations",
                    {
                      keyPath:
                        "eventId"
                    }
                  );

              observationStore
                .createIndex(
                  "by-sync-status",
                  "syncStatus"
                );

              observationStore
                .createIndex(
                  "by-occurred-at",
                  "occurredAt"
                );
            }
          }
        }
      );
  }

  return databasePromise;
}

export async function closeDatabase():
  Promise<void> {
  if (!databasePromise) {
    return;
  }

  const database =
    await databasePromise;

  database.close();

  databasePromise =
    undefined;
}

export async function resetDatabaseForTests():
  Promise<void> {
  await closeDatabase();

  await new Promise<void>(
    (
      resolve,
      reject
    ) => {
      const request =
        indexedDB
          .deleteDatabase(
            DATABASE_NAME
          );

      request.onsuccess =
        () => resolve();

      request.onerror =
        () =>
          reject(
            request.error ??
              new Error(
                "Failed to delete test database."
              )
          );

      request.onblocked =
        () =>
          reject(
            new Error(
              "Test database deletion was blocked by an open connection."
            )
          );
    }
  );
}