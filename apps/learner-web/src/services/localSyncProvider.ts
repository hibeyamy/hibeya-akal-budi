import type {
  SessionSyncProvider
} from "@akal-budi/offline";

export const localSyncProvider:
  SessionSyncProvider = {
    async syncSession(session) {
      console.info(
        "Simulated sync:",
        session
      );

      return {
        sessionId: session.id,
        success: true
      };
    }
  };
  