export const SKILL_MASTERY_POLICY = {
  minimumObservations:
    2,

  masteryScoreThreshold:
    0.75
} as const;


export type SkillMasteryLevel =
  | "unobserved"
  | "exploring"
  | "developing"
  | "mastered";


export interface SkillEvidenceMapping {
  skillId: string;

  role:
    "primary" |
    "supporting";

  weight: number;
}


export interface SkillMasteryEvidenceInput {
  sessionId: string;

  activityId: string;

  completedAt: number;

  correct: number;

  incorrect: number;

  attempts: number;

  durationSeconds: number;

  skillMappings:
    readonly SkillEvidenceMapping[];
}


export interface SkillMasteryRecord {
  skillId: string;

  successfulAttempts:
    number;

  unsuccessfulAttempts:
    number;

  weightedEvidence:
    number;

  totalWeight:
    number;

  observationCount:
    number;

  masteryScore:
    number;

  level:
    SkillMasteryLevel;

  lastObservedAt:
    number;
}


export interface SkillMasteryState {
  version: 1;

  skills:
    Record<
      string,
      SkillMasteryRecord
    >;

  processedSessionIds:
    string[];

  updatedAt:
    number;
}


export function createEmptySkillMasteryState():
  SkillMasteryState {
  return {
    version:
      1,

    skills:
      {},

    processedSessionIds:
      [],

    updatedAt:
      0
  };
}


function clamp01(
  value: number
): number {
  return Math.max(
    0,
    Math.min(
      1,
      value
    )
  );
}


export function classifySkillMastery(
  observationCount: number,
  masteryScore: number
): SkillMasteryLevel {
  if (
    observationCount <=
      0
  ) {
    return "unobserved";
  }

  if (
    observationCount >=
      SKILL_MASTERY_POLICY.minimumObservations &&
    masteryScore >=
      SKILL_MASTERY_POLICY.masteryScoreThreshold
  ) {
    return "mastered";
  }

  if (
    masteryScore >=
      0.5
  ) {
    return "developing";
  }

  return "exploring";
}


export function applySkillMasteryEvidence(
  current:
    SkillMasteryState,
  evidence:
    SkillMasteryEvidenceInput
): SkillMasteryState {
  if (
    current.processedSessionIds.includes(
      evidence.sessionId
    )
  ) {
    return current;
  }

  const attempts =
    Math.max(
      0,
      evidence.attempts
    );

  const accuracy =
    attempts > 0
      ? clamp01(
          evidence.correct /
            attempts
        )
      : 0;

  const nextSkills = {
    ...current.skills
  };

  for (
    const mapping
    of evidence.skillMappings
  ) {
    if (
      !mapping.skillId ||
      !Number.isFinite(
        mapping.weight
      ) ||
      mapping.weight <=
        0
    ) {
      continue;
    }

    const previous =
      current.skills[
        mapping.skillId
      ];

    const weightedEvidence =
      (
        previous?.weightedEvidence ??
        0
      ) +
      accuracy *
        mapping.weight;

    const totalWeight =
      (
        previous?.totalWeight ??
        0
      ) +
      mapping.weight;

    const observationCount =
      (
        previous?.observationCount ??
        0
      ) +
      1;

    const masteryScore =
      totalWeight > 0
        ? clamp01(
            weightedEvidence /
              totalWeight
          )
        : 0;

    nextSkills[
      mapping.skillId
    ] = {
      skillId:
        mapping.skillId,

      successfulAttempts:
        (
          previous?.successfulAttempts ??
          0
        ) +
        Math.max(
          0,
          evidence.correct
        ),

      unsuccessfulAttempts:
        (
          previous?.unsuccessfulAttempts ??
          0
        ) +
        Math.max(
          0,
          evidence.incorrect
        ),

      weightedEvidence,

      totalWeight,

      observationCount,

      masteryScore,

      level:
        classifySkillMastery(
          observationCount,
          masteryScore
        ),

      lastObservedAt:
        evidence.completedAt
    };
  }

  return {
    version:
      1,

    skills:
      nextSkills,

    processedSessionIds: [
      ...current.processedSessionIds,
      evidence.sessionId
    ],

    updatedAt:
      evidence.completedAt
  };
}


export function getMasteredSkillIds(
  state:
    SkillMasteryState
): string[] {
  return Object.values(
    state.skills
  )
    .filter(
      record =>
        record.level ===
          "mastered"
    )
    .map(
      record =>
        record.skillId
    )
    .sort();
}
