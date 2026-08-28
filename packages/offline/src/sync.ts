import type {
  StoredSession,
  StoredAdaptiveObservation
} from "./database";

import {
  getPendingSessions,
  markSessionSynced
} from "./session.repository";

import {
  getPendingAdaptiveObservations,
  markAdaptiveObservationSynced
} from "./adaptiveObservation.repository";


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
  const sessions =
    await getPendingSessions();

  let succeeded = 0;
  let failed = 0;


  for (
    const session of sessions
  ) {
    try {
      const result =
        await provider.syncSession(
          session
        );


      if (result.success) {
        await markSessionSynced(
          session.id
        );

        succeeded += 1;
      } else {
        /*
         * Keep the session pending.
         *
         * A failure may simply mean:
         * - no internet
         * - temporary Supabase outage
         * - transient timeout
         *
         * Pending sessions remain retryable.
         */
        failed += 1;
      }
    } catch {
      failed += 1;
    }
  }


  return {
    attempted:
      sessions.length,

    succeeded,

    failed
  };
}



export interface AdaptiveObservationSyncResult {
  eventId:
    string;

  success:
    boolean;

  error?:
    string;
}


export interface AdaptiveObservationSyncProvider {
  syncAdaptiveObservation(
    observation:
      StoredAdaptiveObservation
  ):
    Promise<
      AdaptiveObservationSyncResult
    >;
}


export async function processPendingAdaptiveObservations(
  provider:
    AdaptiveObservationSyncProvider
):
  Promise<
    SyncQueueResult
  > {
  const observations =
    await getPendingAdaptiveObservations();

  let succeeded =
    0;

  let failed =
    0;

  for (
    const observation
    of observations
  ) {
    try {
      const result =
        await provider
          .syncAdaptiveObservation(
            observation
          );

      if (
        result.success
      ) {
        await markAdaptiveObservationSynced(
          observation.eventId
        );

        succeeded +=
          1;
      } else {
        failed +=
          1;
      }
    } catch {
      failed +=
        1;
    }
  }

  return {
    attempted:
      observations.length,

    succeeded,

    failed
  };
}
