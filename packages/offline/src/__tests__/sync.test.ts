import "fake-indexeddb/auto";

import {
  beforeEach,
  describe,
  expect,
  it
} from "vitest";

import {
  resetDatabaseForTests,
  getDatabase,
  type StoredSession
} from "../database";

import {
  createLocalSession,
  getLocalSession
} from "../session.repository";

import {
  processPendingSessions,
  type SessionSyncProvider
} from "../sync";


async function markSessionCompletedForSyncTest(
  sessionId: string,
  result: NonNullable<StoredSession["result"]>
): Promise<void> {
  const database = await getDatabase();
  const session = await database.get("sessions", sessionId);

  if (!session) {
    throw new Error(`Sync test session not found: ${sessionId}`);
  }

  session.result = result;
  session.completedAt = result.completedAt;
  session.updatedAt = result.completedAt;
  session.syncStatus = "pending";

  await database.put("sessions", session);
}


describe(
  "offline sync queue",
  () => {
    beforeEach(
      async () => {
        await resetDatabaseForTests();
      }
    );


    it(
      "marks successfully synced sessions as synced",
      async () => {
        await createLocalSession({
          id:
            "sync-success",

          activityId:
            "warna-merah-001",

          activityVersion:
            1,

          startedAt:
            1000
        });

        await markSessionCompletedForSyncTest(
          "sync-success",
          {
            activityId:
              "warna-merah-001",

            activityVersion:
              1,

            correct:
              1,

            incorrect:
              0,

            attempts:
              1,

            durationSeconds:
              1,

            completedAt:
              2000
          }
        );


        const provider:
          SessionSyncProvider = {
            async syncSession(
              session
            ) {
              return {
                sessionId:
                  session.id,

                success:
                  true
              };
            }
          };


        const result =
          await processPendingSessions(
            provider
          );


        expect(
          result.attempted
        ).toBe(1);

        expect(
          result.succeeded
        ).toBe(1);

        expect(
          result.failed
        ).toBe(0);


        const session =
          await getLocalSession(
            "sync-success"
          );


        expect(
          session?.syncStatus
        ).toBe(
          "synced"
        );
      }
    );


    it(
      "keeps failed sessions pending for retry",
      async () => {
        await createLocalSession({
          id:
            "sync-failed",

          activityId:
            "warna-merah-001",

          activityVersion:
            1,

          startedAt:
            1000
        });

        await markSessionCompletedForSyncTest(
          "sync-failed",
          {
            activityId:
              "warna-merah-001",

            activityVersion:
              1,

            correct:
              1,

            incorrect:
              0,

            attempts:
              1,

            durationSeconds:
              1,

            completedAt:
              2000
          }
        );


        const provider:
          SessionSyncProvider = {
            async syncSession(
              session
            ) {
              return {
                sessionId:
                  session.id,

                success:
                  false,

                error:
                  "Temporary failure"
              };
            }
          };


        const result =
          await processPendingSessions(
            provider
          );


        expect(
          result.attempted
        ).toBe(1);

        expect(
          result.succeeded
        ).toBe(0);

        expect(
          result.failed
        ).toBe(1);


        const session =
          await getLocalSession(
            "sync-failed"
          );


        expect(
          session?.syncStatus
        ).toBe(
          "pending"
        );
      }
    );


    it(
      "keeps sessions pending when provider throws",
      async () => {
        await createLocalSession({
          id:
            "sync-exception",

          activityId:
            "warna-merah-001",

          activityVersion:
            1,

          startedAt:
            1000
        });

        await markSessionCompletedForSyncTest(
          "sync-exception",
          {
            activityId:
              "warna-merah-001",

            activityVersion:
              1,

            correct:
              1,

            incorrect:
              0,

            attempts:
              1,

            durationSeconds:
              1,

            completedAt:
              2000
          }
        );


        const provider:
          SessionSyncProvider = {
            async syncSession() {
              throw new Error(
                "Network unavailable"
              );
            }
          };


        const result =
          await processPendingSessions(
            provider
          );


        expect(
          result.failed
        ).toBe(1);


        const session =
          await getLocalSession(
            "sync-exception"
          );


        expect(
          session?.syncStatus
        ).toBe(
          "pending"
        );
      }
    );
  }
);
