import {
  supabase
} from "../lib/supabase";

export interface LearnerDevice {
  id: string;
  childId: string;
  deviceName:
    string | null;
  activatedAt: string;
  lastSeenAt:
    string | null;
  revokedAt:
    string | null;
}

export interface ActivationCode {
  code: string;
  expiresAt: string;
}

export async function createActivationCode(
  childId: string
): Promise<ActivationCode> {
  const {
    data,
    error
  } =
    await supabase.rpc(
      "create_learner_device_activation",
      {
        p_child_id:
          childId
      }
    );

  if (error) {
    throw error;
  }

  const result =
    data?.[0];

  if (!result) {
    throw new Error(
      "Kod pengaktifan tidak dapat dijana."
    );
  }

  return {
    code:
      result.activation_code,

    expiresAt:
      result.activation_expires_at
  };
}


export async function getLearnerDevices():
  Promise<LearnerDevice[]> {
  const {
    data,
    error
  } =
    await supabase
      .from(
        "learner_devices"
      )
      .select(
        "id,child_id,device_name,activated_at,last_seen_at,revoked_at"
      )
      .order(
        "activated_at",
        {
          ascending:
            false
        }
      );

  if (error) {
    throw error;
  }

  return (
    data ?? []
  ).map(
    (row) => ({
      id:
        row.id,

      childId:
        row.child_id,

      deviceName:
        row.device_name,

      activatedAt:
        row.activated_at,

      lastSeenAt:
        row.last_seen_at,

      revokedAt:
        row.revoked_at
    })
  );
}


export async function revokeLearnerDevice(
  deviceId: string
): Promise<void> {
  const {
    error
  } =
    await supabase.rpc(
      "revoke_learner_device",
      {
        p_device_id:
          deviceId
      }
    );

  if (error) {
    throw error;
  }
}
