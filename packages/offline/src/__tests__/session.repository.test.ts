import "fake-indexeddb/auto";

import {
  beforeEach,
  describe,
  expect,
  it
} from "vitest";

import {
  resetDatabaseForTests
} from "../database";

import {
  addLocalAnswer,
  completeLocalSession,
  createLocalSession,
  deleteLocalSession,
  getLatestIncompleteSession,
  getLatestIncompleteSessionForActivity,
  getLocalSession,
  getPendingSessions,
  markSessionSynced
} from "../session.repository";

describe(
  "offline session repository",
  () => {
    beforeEach(async () => {
      await resetDatabaseForTests();
    });

    it(
      "creates and retrieves a local session",
      async () => {
        await createLocalSession({
          id: "session-1",
          activityId:
            "warna-merah-001",
          activityVersion: 1,
          startedAt: 1000
        });

        const session =
          await getLocalSession(
            "session-1"
          );

        expect(session)
          .toBeDefined();

        expect(
          session?.activityId
        ).toBe(
          "warna-merah-001"
        );

        expect(
          session?.syncStatus
        ).toBe(
          "pending"
        );

        expect(
          session?.answers
        ).toEqual([]);
      }
    );

    it(
      "stores answers in a session",
      async () => {
        await createLocalSession({
          id: "session-2",
          activityId:
            "warna-merah-001",
          activityVersion: 1,
          startedAt: 1000
        });

        await addLocalAnswer(
          "session-2",
          {
            optionId:
              "apple-green",

            correct:
              false,

            answeredAt:
              2000
          }
        );

        const session =
          await getLocalSession(
            "session-2"
          );

        expect(
          session?.answers
        ).toHaveLength(1);

        expect(
          session?.answers[0]
            ?.correct
        ).toBe(false);
      }
    );

    it(
      "returns the latest incomplete session",
      async () => {
        await createLocalSession({
          id: "session-old",
          activityId:
            "warna-merah-001",
          activityVersion: 1,
          startedAt: 1000
        });

        await new Promise(
          (resolve) =>
            setTimeout(
              resolve,
              5
            )
        );

        await createLocalSession({
          id: "session-new",
          activityId:
            "warna-merah-001",
          activityVersion: 1,
          startedAt: 2000
        });

        const latest =
          await getLatestIncompleteSession();

        expect(
          latest?.id
        ).toBe(
          "session-new"
        );
      }
    );

    it(
      "stores a completed result",
      async () => {
        await createLocalSession({
          id: "session-3",
          activityId:
            "warna-merah-001",
          activityVersion: 1,
          startedAt: 1000
        });

        await completeLocalSession(
          "session-3",
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
              5,

            completedAt:
              6000
          }
        );

        const session =
          await getLocalSession(
            "session-3"
          );

        expect(
          session?.completedAt
        ).toBe(6000);

        expect(
          session?.result
            ?.correct
        ).toBe(1);
      }
    );

    it(
      "marks a session as synced",
      async () => {
        await createLocalSession({
          id: "session-4",
          activityId:
            "warna-merah-001",
          activityVersion: 1,
          startedAt: 1000
        });

        await markSessionSynced(
          "session-4"
        );

        const session =
          await getLocalSession(
            "session-4"
          );

        expect(
          session?.syncStatus
        ).toBe(
          "synced"
        );
      }
    );

    it(
      "returns only pending sessions",
      async () => {
        await createLocalSession({
          id:
            "session-pending",

          activityId:
            "warna-merah-001",

          activityVersion:
            1,

          startedAt:
            1000
        });

        await createLocalSession({
          id:
            "session-synced",

          activityId:
            "warna-merah-001",

          activityVersion:
            1,

          startedAt:
            1000
        });

        await completeLocalSession(
          "session-pending",
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

        await markSessionSynced(
          "session-synced"
        );

        const pending =
          await getPendingSessions();

        const ids =
          pending.map(
            (session) =>
              session.id
          );

        expect(ids)
          .toContain(
            "session-pending"
          );

        expect(ids)
          .not.toContain(
            "session-synced"
          );
      }
    );

    it(
      "returns the latest compatible incomplete session for an activity",
      async () => {
        await createLocalSession({
          id: "target-old",
          activityId: "warna-merah-001",
          activityVersion: 2,
          startedAt: 1000
        });

        await new Promise((resolve) => setTimeout(resolve, 5));

        await createLocalSession({
          id: "other-new",
          activityId: "warna-bunga-raya-001",
          activityVersion: 1,
          startedAt: 2000
        });

        const target =
          await getLatestIncompleteSessionForActivity(
            "warna-merah-001",
            2
          );

        expect(target?.id).toBe(
          "target-old"
        );
      }
    );

    it(
      "does not resume an incompatible activity version",
      async () => {
        await createLocalSession({
          id: "legacy-version",
          activityId: "warna-merah-001",
          activityVersion: 1,
          startedAt: 1000
        });

        const target =
          await getLatestIncompleteSessionForActivity(
            "warna-merah-001",
            2
          );

        expect(target).toBeUndefined();
      }
    );

    it(
      "keeps the first committed completion immutable on replay",
      async () => {
        await createLocalSession({
          id: "session-idempotent",
          activityId: "warna-merah-001",
          activityVersion: 2,
          startedAt: 1000
        });

        await completeLocalSession(
          "session-idempotent",
          {
            activityId: "warna-merah-001",
            activityVersion: 2,
            correct: 1,
            incorrect: 0,
            attempts: 1,
            durationSeconds: 5,
            completedAt: 6000
          }
        );

        await completeLocalSession(
          "session-idempotent",
          {
            activityId: "warna-merah-001",
            activityVersion: 2,
            correct: 1,
            incorrect: 0,
            attempts: 1,
            durationSeconds: 99,
            completedAt: 99999
          }
        );

        const session =
          await getLocalSession(
            "session-idempotent"
          );

        expect(session?.completedAt).toBe(
          6000
        );
        expect(session?.result?.durationSeconds).toBe(
          5
        );
      }
    );


    it(
      "does not send incomplete sessions to the sync queue",
      async () => {
        await createLocalSession({
          id: "unfinished",
          activityId: "beza-bunga-raya-001",
          activityVersion: 1,
          startedAt: 1000
        });

        const pending =
          await getPendingSessions();

        expect(
          pending.map(
            (session) => session.id
          )
        ).not.toContain(
          "unfinished"
        );
      }
    );

    it(
      "deletes an abandoned incomplete session",
      async () => {
        await createLocalSession({
          id: "abandoned",
          activityId: "beza-bunga-raya-001",
          activityVersion: 1,
          startedAt: 1000
        });

        await deleteLocalSession(
          "abandoned"
        );

        expect(
          await getLocalSession(
            "abandoned"
          )
        ).toBeUndefined();
      }
    );

  }
);
