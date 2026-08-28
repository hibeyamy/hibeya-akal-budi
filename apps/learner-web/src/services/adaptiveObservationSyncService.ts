import {
  getLearnerDevice,
  getNetworkStatus,
  processPendingAdaptiveObservations,
  queueAdaptiveObservation,
  type AdaptiveObservationSyncProvider,
  type QueueAdaptiveObservationInput,
  type StoredAdaptiveObservation
} from "@akal-budi/offline";

import {
  supabase
} from "../lib/supabase";


export async function syncStoredAdaptiveObservation(
  observation:
    StoredAdaptiveObservation
): Promise<void> {
  const device =
    await getLearnerDevice();

  if (!device) {
    throw new Error(
      "Learner device is not activated."
    );
  }

  const {
    error
  } =
    await supabase.rpc(
      "ingest_adaptive_observation",
      {
        p_device_id:
          device.deviceId,

        p_device_token:
          device.deviceToken,

        p_event_id:
          observation.eventId,

        p_occurred_at:
          new Date(
            observation.occurredAt
          ).toISOString(),

        p_authority:
          observation.authority,

        p_fallback_reason:
          observation.fallbackReason,

        p_rollout_bucket:
          observation.rolloutBucket,

        p_rollout_percent:
          observation.rolloutPercent,

        p_legacy_activity_id:
          observation.legacyActivityId,

        p_adaptive_activity_id:
          observation.adaptiveActivityId,

        p_selected_activity_id:
          observation.selectedActivityId
      }
    );

  if (error) {
    throw error;
  }
}


export const adaptiveObservationSyncProvider:
  AdaptiveObservationSyncProvider = {
    async syncAdaptiveObservation(
      observation
    ) {
      try {
        await syncStoredAdaptiveObservation(
          observation
        );

        return {
          eventId:
            observation.eventId,

          success:
            true
        };
      } catch (
        error
      ) {
        return {
          eventId:
            observation.eventId,

          success:
            false,

          error:
            error instanceof
              Error
              ? error.message
              : "Unknown adaptive observation sync error"
        };
      }
    }
  };


export async function flushPendingAdaptiveObservations():
  Promise<void> {
  try {
    const network =
      getNetworkStatus();

    if (
      !network.online
    ) {
      return;
    }

    await processPendingAdaptiveObservations(
      adaptiveObservationSyncProvider
    );
  } catch {
    /*
     * Observation transport is non-blocking.
     */
  }
}


export async function queueAndSyncAdaptiveObservation(
  input:
    QueueAdaptiveObservationInput
): Promise<void> {
  try {
    await queueAdaptiveObservation(
      input
    );

    await flushPendingAdaptiveObservations();
  } catch {
    /*
     * Queue or transport failure must never block learner selection.
     */
  }
}
