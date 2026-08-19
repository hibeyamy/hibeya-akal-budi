import type { StoredSession } from "./database";

import {
  getPendingSessions,
  markSessionFailed,
  markSessionSynced
} from "./session.repository";

export interface SessionSyncResult {
  sessionId: string;
  success: boolean;
  error?: string;
}

export interface SessionSyncProvider {
  syncSession(
    session: StoredSession
  ): Promise<SessionSyncResult>;
}

export interface SyncQueueResult {
  attempted: number;
  succeeded: number;
  failed: number;
}

export async function processPendingSessions(
  provider: SessionSyncProvider
): Promise<SyncQueueResult> {
  const sessions = await getPendingSessions();

  let succeeded = 0;
  let failed = 0;

  for (const session of sessions) {
    try {
      const result = await provider.syncSession(
        session
      );

      if (result.success) {
        await markSessionSynced(
          session.id
        );

        succeeded += 1;
      } else {
        await markSessionFailed(
          session.id
        );

        failed += 1;
      }
    } catch {
      await markSessionFailed(
        session.id
      );

      failed += 1;
    }
  }

  return {
    attempted: sessions.length,
    succeeded,
    failed
  };
}
