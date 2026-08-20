import {
  getDatabase
} from "./database";


const RUNTIME_PROFILE_KEY =
  "learner-runtime-profile";


export type CachedLearnerAgeBand =
  | "2-3"
  | "3-4"
  | "4-5"
  | "5-6";


export type CachedLearnerLanguage =
  | "ms"
  | "en";


export interface CachedLearnerRuntimeProfile {
  childId: string;

  ageBand:
    CachedLearnerAgeBand;

  preferredLanguage:
    CachedLearnerLanguage;

  validatedAt:
    number;
}


export async function saveLearnerRuntimeProfile(
  profile: CachedLearnerRuntimeProfile
): Promise<void> {
  const db =
    await getDatabase();

  await db.put(
    "settings",
    {
      key:
        RUNTIME_PROFILE_KEY,

      value:
        profile
    }
  );
}


export async function getCachedLearnerRuntimeProfile():
  Promise<
    CachedLearnerRuntimeProfile |
    null
  > {
  const db =
    await getDatabase();

  const stored =
    await db.get(
      "settings",
      RUNTIME_PROFILE_KEY
    );

  if (
    !stored ||
    !isRuntimeProfile(
      stored.value
    )
  ) {
    return null;
  }

  return stored.value;
}


export async function clearLearnerRuntimeProfile():
  Promise<void> {
  const db =
    await getDatabase();

  await db.delete(
    "settings",
    RUNTIME_PROFILE_KEY
  );
}


function isRuntimeProfile(
  value: unknown
): value is CachedLearnerRuntimeProfile {
  if (
    typeof value !==
      "object" ||
    value ===
      null
  ) {
    return false;
  }

  const candidate =
    value as Record<
      string,
      unknown
    >;

  return (
    typeof candidate.childId ===
      "string" &&
    isAgeBand(
      candidate.ageBand
    ) &&
    isLanguage(
      candidate.preferredLanguage
    ) &&
    typeof candidate.validatedAt ===
      "number"
  );
}


function isAgeBand(
  value: unknown
): value is CachedLearnerAgeBand {
  return (
    value === "2-3" ||
    value === "3-4" ||
    value === "4-5" ||
    value === "5-6"
  );
}


function isLanguage(
  value: unknown
): value is CachedLearnerLanguage {
  return (
    value === "ms" ||
    value === "en"
  );
}