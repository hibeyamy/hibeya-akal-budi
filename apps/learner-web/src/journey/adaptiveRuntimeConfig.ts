import {
  DEFAULT_ADAPTIVE_ACTIVATION_CONFIG
} from "./adaptiveActivationPolicy";

import type {
  AdaptiveActivationConfig
} from "./adaptiveActivationPolicy";


export const ADAPTIVE_ENABLED_ENV =
  "VITE_HIBEYA_ADAPTIVE_ENABLED";

export const ADAPTIVE_ROLLOUT_PERCENT_ENV =
  "VITE_HIBEYA_ADAPTIVE_ROLLOUT_PERCENT";


type RuntimeEnv =
  Readonly<
    Record<
      string,
      string |
      boolean |
      undefined
    >
  >;


function parseBoolean(
  value:
    unknown
): boolean | null {
  if (
    value ===
      true ||
    value ===
      "true" ||
    value ===
      "1"
  ) {
    return true;
  }

  if (
    value ===
      false ||
    value ===
      "false" ||
    value ===
      "0"
  ) {
    return false;
  }

  return null;
}


function parseRolloutPercent(
  value:
    unknown
): number | null {
  if (
    typeof value !==
      "string" &&
    typeof value !==
      "number"
  ) {
    return null;
  }

  const parsed =
    Number(
      value
    );

  if (
    !Number.isFinite(
      parsed
    ) ||
    parsed <
      0 ||
    parsed >
      100
  ) {
    return null;
  }

  return parsed;
}


export function parseAdaptiveRuntimeConfig(
  env:
    RuntimeEnv
):
  AdaptiveActivationConfig {
  const enabled =
    parseBoolean(
      env[
        ADAPTIVE_ENABLED_ENV
      ]
    );

  const rolloutPercent =
    parseRolloutPercent(
      env[
        ADAPTIVE_ROLLOUT_PERCENT_ENV
      ]
    );

  /*
   * Fail closed:
   * missing or malformed values never enable adaptive authority.
   */
  if (
    enabled !==
      true ||
    rolloutPercent ===
      null
  ) {
    return {
      ...DEFAULT_ADAPTIVE_ACTIVATION_CONFIG
    };
  }

  return {
    enabled:
      true,
    rolloutPercent
  };
}


export function getAdaptiveRuntimeConfig():
  AdaptiveActivationConfig {
  try {
    const env =
      (
        import.meta as
          ImportMeta & {
            env?:
              RuntimeEnv;
          }
      ).env ??
      {};

    return parseAdaptiveRuntimeConfig(
      env
    );
  } catch {
    return {
      ...DEFAULT_ADAPTIVE_ACTIVATION_CONFIG
    };
  }
}
