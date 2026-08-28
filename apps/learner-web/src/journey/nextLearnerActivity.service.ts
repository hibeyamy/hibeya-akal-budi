import type {
  ResolvedPlayableActivity
} from "@akal-budi/content-library";

import {
  getEvidenceAdjustedLearningNeed
} from "@akal-budi/learning-insights";


export interface LearnerSkillProgress {
  skillId: string;

  masteryScore: number;

  observationCount: number;

  level:
    "unobserved" |
    "exploring" |
    "developing" |
    "mastered";
}


export interface NextLearnerActivityInput {
  activities:
    readonly ResolvedPlayableActivity[];

  completedActivityIds:
    readonly string[];

  lastCompletedActivityId:
    string | null;

  skillProgress?:
    readonly LearnerSkillProgress[];
}



function getSkillNeed(
  skillId: string,
  progress:
    ReadonlyMap<
      string,
      LearnerSkillProgress
    >
): number {
  const record =
    progress.get(
      skillId
    );

  if (!record) {
    return 0.5;
  }

  return getEvidenceAdjustedLearningNeed({
    masteryScore:
      record.masteryScore,

    observationCount:
      record.observationCount,

    mastered:
      record.level ===
        "mastered"
  });
}


export function getActivityLearningNeed(
  activity:
    ResolvedPlayableActivity,
  skillProgress:
    readonly LearnerSkillProgress[]
): number {
  if (
    skillProgress.length ===
      0
  ) {
    return 0;
  }

  const progress =
    new Map(
      skillProgress.map(
        record => [
          record.skillId,
          record
        ] as const
      )
    );

  const mappings =
    activity.skillMappings ??
    [];

  if (
    mappings.length ===
      0
  ) {
    return 0;
  }

  let weightedNeed =
    0;

  let totalWeight =
    0;

  for (
    const mapping
    of mappings
  ) {
    const weight =
      Math.max(
        0,
        mapping.weight
      );

    if (
      weight ===
        0
    ) {
      continue;
    }

    const roleMultiplier =
      mapping.role ===
        "primary"
        ? 1
        : 0.5;

    const effectiveWeight =
      weight *
      roleMultiplier;

    weightedNeed +=
      getSkillNeed(
        mapping.skillId,
        progress
      ) *
      effectiveWeight;

    totalWeight +=
      effectiveWeight;
  }

  return totalWeight >
    0
    ? weightedNeed /
        totalWeight
    : 0;
}


function getSequencePosition(
  activities:
    readonly ResolvedPlayableActivity[],
  activity:
    ResolvedPlayableActivity
): number {
  const index =
    activities.findIndex(
      candidate =>
        candidate.id ===
          activity.id
    );

  return index >=
    0
    ? index
    : Number.MAX_SAFE_INTEGER;
}


function rankByLearningNeed(
  candidates:
    readonly ResolvedPlayableActivity[],
  catalogue:
    readonly ResolvedPlayableActivity[],
  skillProgress:
    readonly LearnerSkillProgress[],
  avoidActivityId:
    string | null = null
):
  ResolvedPlayableActivity[] {
  return [...candidates]
    .sort(
      (
        left,
        right
      ) => {
        const needDifference =
          getActivityLearningNeed(
            right,
            skillProgress
          ) -
          getActivityLearningNeed(
            left,
            skillProgress
          );

        if (
          Math.abs(
            needDifference
          ) >
            0.000001
        ) {
          return needDifference;
        }

        if (
          avoidActivityId
        ) {
          const leftIsImmediateRepeat =
            left.id ===
              avoidActivityId;

          const rightIsImmediateRepeat =
            right.id ===
              avoidActivityId;

          if (
            leftIsImmediateRepeat !==
              rightIsImmediateRepeat
          ) {
            return leftIsImmediateRepeat
              ? 1
              : -1;
          }
        }

        const sequenceDifference =
          getSequencePosition(
            catalogue,
            left
          ) -
          getSequencePosition(
            catalogue,
            right
          );

        if (
          sequenceDifference !==
            0
        ) {
          return sequenceDifference;
        }

        return left.id.localeCompare(
          right.id
        );
      }
    );
}


export function selectRemediationActivity({
  activities,
  skillProgress,
  lastCompletedActivityId = null
}: {
  activities:
    readonly ResolvedPlayableActivity[];

  skillProgress:
    readonly LearnerSkillProgress[];

  lastCompletedActivityId?:
    string | null;
}):
  ResolvedPlayableActivity |
  null {
  if (
    activities.length ===
      0 ||
    skillProgress.length ===
      0
  ) {
    return null;
  }

  const ranked =
    rankByLearningNeed(
      activities,
      activities,
      skillProgress,
      lastCompletedActivityId
    );

  const candidate =
    ranked[0];

  if (!candidate) {
    return null;
  }

  const need =
    getActivityLearningNeed(
      candidate,
      skillProgress
    );

  return need >
    0
    ? candidate
    : null;
}



export type LearnerActivitySelectionReason =
  | "catalogue-fallback"
  | "learning-need"
  | "remediation"
  | "cycle-fallback";


export interface LearnerActivitySelectionDecision {
  activity:
    ResolvedPlayableActivity;

  reason:
    LearnerActivitySelectionReason;

  learningNeed:
    number;

  difficultyFit:
    number;
}


export function getActivityDifficultyFit(
  activity:
    ResolvedPlayableActivity,
  skillProgress:
    readonly LearnerSkillProgress[]
): number {
  const primarySkillId =
    activity.primarySkillIds[0];

  const progress =
    primarySkillId
      ? skillProgress.find(
          record =>
            record.skillId ===
              primarySkillId
        )
      : undefined;

  const preferredDifficulty =
    !progress ||
    progress.observationCount <
      2 ||
    progress.level ===
      "unobserved" ||
    progress.level ===
      "exploring"
      ? 1
      : 2;

  return Math.max(
    0,
    1 -
      Math.abs(
        activity.difficulty -
        preferredDifficulty
      ) *
        0.5
  );
}


export function resolveNextLearnerActivityDecision(
  input:
    NextLearnerActivityInput
):
  LearnerActivitySelectionDecision |
  null {
  const activity =
    resolveNextLearnerActivity(
      input
    );

  if (!activity) {
    return null;
  }

  const learningNeed =
    getActivityLearningNeed(
      activity,
      input.skillProgress ??
        []
    );

  const difficultyFit =
    getActivityDifficultyFit(
      activity,
      input.skillProgress ??
        []
    );

  const hasProgress =
    (input.skillProgress?.length ??
      0) >
    0;

  const allCompleted =
    input.activities.length >
      0 &&
    input.activities.every(
      candidate =>
        input.completedActivityIds.includes(
          candidate.id
        )
    );

  const reason:
    LearnerActivitySelectionReason =
      !hasProgress
        ? "catalogue-fallback"
        : allCompleted &&
            learningNeed >
              0
          ? "remediation"
          : allCompleted
            ? "cycle-fallback"
            : "learning-need";

  return {
    activity,
    reason,
    learningNeed,
    difficultyFit
  };
}


export function resolveNextLearnerActivity({
  activities,
  completedActivityIds,
  lastCompletedActivityId,
  skillProgress = []
}: NextLearnerActivityInput):
  ResolvedPlayableActivity |
  null {
  if (
    activities.length ===
      0
  ) {
    return null;
  }

  const completed =
    new Set(
      completedActivityIds
    );

  const uncompleted =
    activities.filter(
      activity =>
        !completed.has(
          activity.id
        )
    );

  if (
    uncompleted.length >
      0
  ) {
    if (
      skillProgress.length ===
        0
    ) {
      return (
        uncompleted[0] ??
        null
      );
    }

    return (
      rankByLearningNeed(
        uncompleted,
        activities,
        skillProgress
      )[0] ??
      null
    );
  }

  const remediation =
    selectRemediationActivity({
      activities,
      skillProgress,
      lastCompletedActivityId
    });

  if (
    remediation
  ) {
    return remediation;
  }

  const currentIndex =
    lastCompletedActivityId
      ? activities.findIndex(
          activity =>
            activity.id ===
              lastCompletedActivityId
        )
      : -1;

  if (
    currentIndex <
      0
  ) {
    return (
      activities[0] ??
      null
    );
  }

  const nextIndex =
    (
      currentIndex +
      1
    ) %
    activities.length;

  return (
    activities[nextIndex] ??
    activities[0] ??
    null
  );
}
