import {
  applySkillMasteryEvidence,
  createEmptySkillMasteryState,
  getMasteredSkillIds,
  type SkillEvidenceMapping,
  type SkillMasteryState
} from "@akal-budi/learning-insights";

import {
  getLearnerSkillMasteryState,
  saveLearnerSkillMasteryState
} from "@akal-budi/offline";

import type {
  GameSessionResult
} from "@akal-budi/game-runtime";


function toDomainState(
  stored:
    Awaited<
      ReturnType<
        typeof getLearnerSkillMasteryState
      >
    >
): SkillMasteryState {
  return {
    ...createEmptySkillMasteryState(),
    ...stored
  } as SkillMasteryState;
}


export async function getLearnerSkillProgress():
  Promise<
    Array<{
      skillId: string;
      masteryScore: number;
      observationCount: number;
      level:
        "unobserved" |
        "exploring" |
        "developing" |
        "mastered";
    }>
  > {
  const stored =
    await getLearnerSkillMasteryState();

  const state =
    toDomainState(
      stored
    );

  return Object.values(
    state.skills
  )
    .map(
      record => ({
        skillId:
          record.skillId,
        masteryScore:
          record.masteryScore,
        observationCount:
          record.observationCount,
        level:
          record.level
      })
    )
    .sort(
      (
        left,
        right
      ) =>
        left.skillId.localeCompare(
          right.skillId
        )
    );
}

export async function getLearnerMasteredSkillIds():
  Promise<string[]> {
  const stored =
    await getLearnerSkillMasteryState();

  return getMasteredSkillIds(
    toDomainState(
      stored
    )
  );
}


export async function recordSessionSkillMastery({
  sessionId,
  result,
  skillMappings
}: {
  sessionId: string;
  result: GameSessionResult;
  skillMappings:
    readonly SkillEvidenceMapping[];
}): Promise<string[]> {
  const stored =
    await getLearnerSkillMasteryState();

  const current =
    toDomainState(
      stored
    );

  const alreadyProcessed =
    current.processedSessionIds.includes(
      sessionId
    );

  const next =
    applySkillMasteryEvidence(
      current,
      {
        sessionId,
        activityId:
          result.activityId,
        completedAt:
          result.completedAt,
        correct:
          result.correct,
        incorrect:
          result.incorrect,
        attempts:
          result.attempts,
        durationSeconds:
          result.durationSeconds,
        skillMappings
      }
    );

  if (
    !alreadyProcessed
  ) {
    await saveLearnerSkillMasteryState(
      next
    );
  }

  return getMasteredSkillIds(
    next
  );
}
