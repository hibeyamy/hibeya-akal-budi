import type {
  SessionSyncProvider
} from "@akal-budi/offline";

import {
  syncStoredSession
} from "./progressSyncService";


export const localSyncProvider:
  SessionSyncProvider = {
    async syncSession(
      session
    ) {
      try {
        await syncStoredSession(
          session
        );

        return {
          sessionId:
            session.id,

          success:
            true
        };
      } catch (error) {
        const message =
          error instanceof Error
            ? error.message
            : "Unknown sync error";

        return {
          sessionId:
            session.id,

          success:
            false,

          error:
            message
        };
      }
    }
  };
  