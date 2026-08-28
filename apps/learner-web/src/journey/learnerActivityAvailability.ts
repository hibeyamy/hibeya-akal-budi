import {
  getPlayableActivitiesForAgeBand,
  type ResolvedPlayableActivity
} from "@akal-budi/content-library";

import type {
  LearnerAgeBand
} from "../services/deviceActivationService";

export function getLearnerActivitiesForAgeBand(
  ageBand: LearnerAgeBand
): ResolvedPlayableActivity[] {
  return getPlayableActivitiesForAgeBand(
    ageBand
  );
}

export function hasLearnerContentForAgeBand(
  ageBand: LearnerAgeBand
): boolean {
  return getLearnerActivitiesForAgeBand(
    ageBand
  ).length > 0;
}
