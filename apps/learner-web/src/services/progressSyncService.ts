import {
  getLearnerDevice,
  type StoredSession
} from "@akal-budi/offline";

import {
  supabase
} from "../lib/supabase";


export async function syncStoredSession(
  session: StoredSession
): Promise<void> {
  if (
    !session.result ||
    !session.completedAt
  ) {
    throw new Error(
      "Only completed sessions can be synchronised."
    );
  }


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
      "sync_learner_session",
      {
        p_device_id:
          device.deviceId,

        p_device_token:
          device.deviceToken,

        p_session_id:
          session.id,

        p_activity_id:
          session.activityId,

        p_activity_version:
          session.activityVersion,

        p_started_at:
          new Date(
            session.startedAt
          ).toISOString(),

        p_completed_at:
          new Date(
            session.completedAt
          ).toISOString(),

        p_correct_count:
          session.result.correct,

        p_incorrect_count:
          session.result.incorrect,

        p_attempts:
          session.result.attempts,

        p_duration_seconds:
          session.result.durationSeconds
      }
    );


  if (error) {
    throw error;
  }
}
