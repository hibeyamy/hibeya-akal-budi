import {
  SKILL_MASTERY_POLICY
} from "./mastery";


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


export function getMasteryEvidenceConfidence(
  observationCount: number
): number {
  if (
    !Number.isFinite(
      observationCount
    ) ||
    observationCount <=
      0
  ) {
    return 0;
  }

  return clamp01(
    observationCount /
      SKILL_MASTERY_POLICY.minimumObservations
  );
}


export function getEvidenceAdjustedLearningNeed({
  masteryScore,
  observationCount,
  mastered
}: {
  masteryScore: number;
  observationCount: number;
  mastered: boolean;
}): number {
  if (
    mastered
  ) {
    return 0;
  }

  const rawNeed =
    1 -
    clamp01(
      masteryScore
    );

  const confidence =
    getMasteryEvidenceConfidence(
      observationCount
    );

  const neutralNeed =
    0.5;

  return (
    neutralNeed *
      (
        1 -
        confidence
      ) +
    rawNeed *
      confidence
  );
}
