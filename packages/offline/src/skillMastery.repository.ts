import {
  getDatabase
} from "./database";


const MASTERY_KEY =
  "learner-skill-mastery-v1";


export type StoredSkillMasteryLevel =
  | "unobserved"
  | "exploring"
  | "developing"
  | "mastered";


export interface StoredSkillMasteryRecord {
  skillId: string;
  successfulAttempts: number;
  unsuccessfulAttempts: number;
  weightedEvidence: number;
  totalWeight: number;
  observationCount: number;
  masteryScore: number;
  level: StoredSkillMasteryLevel;
  lastObservedAt: number;
}


export interface LearnerSkillMasteryState {
  version: 1;

  skills:
    Record<
      string,
      StoredSkillMasteryRecord
    >;

  processedSessionIds:
    string[];

  updatedAt:
    number;
}


const emptyState:
  LearnerSkillMasteryState = {
    version:
      1,
    skills:
      {},
    processedSessionIds:
      [],
    updatedAt:
      0
  };


export async function getLearnerSkillMasteryState():
  Promise<LearnerSkillMasteryState> {
  const db =
    await getDatabase();

  const stored =
    await db.get(
      "settings",
      MASTERY_KEY
    );

  if (
    !stored ||
    !isMasteryState(
      stored.value
    )
  ) {
    return {
      ...emptyState,
      skills:
        {},
      processedSessionIds:
        []
    };
  }

  return normalizeMasteryState(
    stored.value
  );
}


export async function saveLearnerSkillMasteryState(
  state:
    LearnerSkillMasteryState
): Promise<void> {
  const db =
    await getDatabase();

  await db.put(
    "settings",
    {
      key:
        MASTERY_KEY,
      value:
        normalizeMasteryState(
          state
        )
    }
  );
}


export async function clearLearnerSkillMasteryState():
  Promise<void> {
  const db =
    await getDatabase();

  await db.delete(
    "settings",
    MASTERY_KEY
  );
}


function normalizeMasteryState(
  value:
    LearnerSkillMasteryState
): LearnerSkillMasteryState {
  return {
    version:
      1,

    skills:
      value.skills ??
      {},

    processedSessionIds:
      Array.from(
        new Set(
          Array.isArray(
            value.processedSessionIds
          )
            ? value.processedSessionIds.filter(
                id =>
                  typeof id ===
                    "string" &&
                  id.length >
                    0
              )
            : []
        )
      ),

    updatedAt:
      Number.isFinite(
        value.updatedAt
      )
        ? value.updatedAt
        : 0
  };
}


function isMasteryState(
  value: unknown
): value is LearnerSkillMasteryState {
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
    candidate.version ===
      1 &&
    typeof candidate.skills ===
      "object" &&
    candidate.skills !==
      null &&
    Array.isArray(
      candidate.processedSessionIds
    ) &&
    typeof candidate.updatedAt ===
      "number"
  );
}
