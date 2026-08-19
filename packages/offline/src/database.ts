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
}

const DATABASE_NAME = "hibeya-akal-budi";
const DATABASE_VERSION = 1;

let databasePromise:
  | Promise<IDBPDatabase<AkalBudiDatabase>>
  | undefined;

export function getDatabase() {
  if (!databasePromise) {
    databasePromise = openDB<AkalBudiDatabase>(
      DATABASE_NAME,
      DATABASE_VERSION,
      {
        upgrade(database) {
          const sessionStore =
            database.createObjectStore(
              "sessions",
              {
                keyPath: "id"
              }
            );

          sessionStore.createIndex(
            "by-sync-status",
            "syncStatus"
          );

          sessionStore.createIndex(
            "by-activity-id",
            "activityId"
          );

          sessionStore.createIndex(
            "by-updated-at",
            "updatedAt"
          );
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
  databasePromise = undefined;
}

export async function resetDatabaseForTests():
  Promise<void> {
  await closeDatabase();

  await new Promise<void>(
    (resolve, reject) => {
      const request =
        indexedDB.deleteDatabase(
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
