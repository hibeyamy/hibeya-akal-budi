import {
  supabase
} from "../lib/supabase";


export interface DeviceActivationResult {
  deviceId: string;
  childId: string;
  deviceToken: string;
}


export interface DeviceValidationResult {
  valid: boolean;
  childId:
    string | null;
}


export async function exchangeActivationCode(
  activationCode: string,
  deviceName:
    string | null
): Promise<DeviceActivationResult> {
  const cleanedCode =
    activationCode
      .replace(
        /\D/g,
        ""
      )
      .slice(
        0,
        6
      );


  if (
    cleanedCode.length !== 6
  ) {
    throw new Error(
      "Kod pengaktifan mesti mempunyai 6 digit."
    );
  }


  const {
    data,
    error
  } =
    await supabase.rpc(
      "exchange_learner_device_activation",
      {
        p_activation_code:
          cleanedCode,

        p_device_name:
          deviceName
      }
    );


  if (error) {
    throw error;
  }


  const result =
    data?.[0];


  if (!result) {
    throw new Error(
      "Pengaktifan peranti gagal."
    );
  }


  return {
    deviceId:
      result.device_id,

    childId:
      result.child_id,

    deviceToken:
      result.device_token
  };
}


export async function validateLearnerDevice(
  deviceId: string,
  deviceToken: string
): Promise<DeviceValidationResult> {
  const {
    data,
    error
  } =
    await supabase.rpc(
      "validate_learner_device",
      {
        p_device_id:
          deviceId,

        p_device_token:
          deviceToken
      }
    );


  if (error) {
    throw error;
  }


  const result =
    data?.[0];


  if (!result) {
    return {
      valid:
        false,

      childId:
        null
    };
  }


  return {
    valid:
      result.valid,

    childId:
      result.child_id
  };
}

export type LearnerAgeBand =
  | "2-3"
  | "3-4"
  | "4-5"
  | "5-6";


export type LearnerLanguage =
  | "ms"
  | "en";


export interface LearnerRuntimeProfile {
  childId: string;

  ageBand:
    LearnerAgeBand;

  preferredLanguage:
    LearnerLanguage;
}
export async function getLearnerRuntimeProfile(
  deviceId: string,
  deviceToken: string
): Promise<LearnerRuntimeProfile> {

  const {
    data,
    error
  } =
    await supabase.rpc(
      "get_learner_runtime_profile",
      {
        p_device_id:
          deviceId,

        p_device_token:
          deviceToken
      }
    );

  if (error) {
    throw error;
  }

  const result =
    data?.[0];

  if (!result) {
    throw new Error(
      "Profil pembelajaran tidak ditemui."
    );
  }

  if (
    !isLearnerAgeBand(
      result.age_band
    )
  ) {
    throw new Error(
      "Julat umur pembelajaran tidak sah."
    );
  }

  if (
    !isLearnerLanguage(
      result.preferred_language
    )
  ) {
    throw new Error(
      "Bahasa pembelajaran tidak sah."
    );
  }

  return {
    childId:
      result.child_id,

    ageBand:
      result.age_band,

    preferredLanguage:
      result.preferred_language
  };
}


function isLearnerAgeBand(
  value: string
): value is LearnerAgeBand {
  return (
    value === "2-3" ||
    value === "3-4" ||
    value === "4-5" ||
    value === "5-6"
  );
}


function isLearnerLanguage(
  value: string
): value is LearnerLanguage {
  return (
    value === "ms" ||
    value === "en"
  );
}