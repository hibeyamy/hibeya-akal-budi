import type {
  AgeBand
} from "@akal-budi/content-architecture";

import {
  getPlayableActivitiesForAgeBand,
  type ResolvedPlayableActivity
} from "./catalogue";


export interface LearnerEligibilityInput {
  ageBand:
    AgeBand;

  masteredSkillIds:
    readonly string[];
}


export function isActivityPrerequisiteEligible(
  activity:
    ResolvedPlayableActivity,
  masteredSkillIds:
    ReadonlySet<string>
): boolean {
  return activity
    .requiredPrerequisiteSkillIds
    .every(
      skillId =>
        masteredSkillIds.has(
          skillId
        )
    );
}


export function getEligibleActivitiesForLearner({
  ageBand,
  masteredSkillIds
}: LearnerEligibilityInput):
  ResolvedPlayableActivity[] {
  const mastered =
    new Set(
      masteredSkillIds
    );

  return getPlayableActivitiesForAgeBand(
    ageBand
  ).filter(
    activity =>
      isActivityPrerequisiteEligible(
        activity,
        mastered
      )
  );
}
