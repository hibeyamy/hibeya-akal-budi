import "fake-indexeddb/auto";

import {
  beforeEach,
  describe,
  expect,
  it
} from "vitest";

import {
  createLocalSession,
  getLocalSession
} from "../session.repository";

import {
  processPendingSessions,
  type SessionSyncProvider
} from "../sync";

describe("offline sync queue", () => {
  beforeEach(async () => {
    await new Promise<void>((resolve, reject) => {
      const request = indexedDB.deleteDatabase(
        "hibeya-akal-budi"
      );

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
      request.onblocked = () => resolve();
    });
  });

  it("marks successfully synced sessions as synced", async () => {
    await createLocalSession({
      id: "sync-success",
      activityId: "warna-merah-001",
      activityVersion: 1,
      startedAt: 1000
    });

    const provider: SessionSyncProvider = {
      async syncSession(session) {
        return {
          sessionId: session.id,
          success: true
        };
      }
    };

    const result =
      await processPendingSessions(
        provider
      );

    expect(result.attempted).toBe(1);
    expect(result.succeeded).toBe(1);
    expect(result.failed).toBe(0);

    const session =
      await getLocalSession(
        "sync-success"
      );

    expect(session?.syncStatus)
      .toBe("synced");
  });

  it("marks failed sessions as failed", async () => {
    await createLocalSession({
      id: "sync-failed",
      activityId: "warna-merah-001",
      activityVersion: 1,
      startedAt: 1000
    });

    const provider: SessionSyncProvider = {
      async syncSession(session) {
        return {
          sessionId: session.id,
          success: false,
          error: "Simulated failure"
        };
      }
    };

    const result =
      await processPendingSessions(
        provider
      );

    expect(result.attempted).toBe(1);
    expect(result.succeeded).toBe(0);
    expect(result.failed).toBe(1);

    const session =
      await getLocalSession(
        "sync-failed"
      );

    expect(session?.syncStatus)
      .toBe("failed");
  });
});
