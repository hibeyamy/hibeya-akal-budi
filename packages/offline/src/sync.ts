import type { StoredSession } from "./database";

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
