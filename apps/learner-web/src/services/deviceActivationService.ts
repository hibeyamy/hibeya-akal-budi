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
