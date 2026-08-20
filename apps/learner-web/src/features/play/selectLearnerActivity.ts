import {
  getPlayableActivitiesForAgeBand,
  type ResolvedPlayableActivity
} from "@akal-budi/content-library";

import type {
  LearnerAgeBand
} from "../../services/deviceActivationService";


export interface LearnerActivitySelectionInput {
  ageBand:
    LearnerAgeBand;

  lastCompletedActivityId:
    string | null;
}


export function selectLearnerActivity({
  ageBand,
  lastCompletedActivityId
}: LearnerActivitySelectionInput):
  ResolvedPlayableActivity |
  null {

  const eligible =
    getPlayableActivitiesForAgeBand(
      ageBand
    );

  if (
    eligible.length ===
    0
  ) {
    return null;
  }

  const ordered =
    [...eligible].sort(
      (a, b) => {

        const aMalaysia =
          a.blueprint
            .malaysiaElements
            .length > 0
            ? 1
            : 0;

        const bMalaysia =
          b.blueprint
            .malaysiaElements
            .length > 0
            ? 1
            : 0;

        if (
          aMalaysia !==
          bMalaysia
        ) {
          return (
            bMalaysia -
            aMalaysia
          );
        }

        if (
          a.blueprint
            .difficulty !==
          b.blueprint
            .difficulty
        ) {
          return (
            a.blueprint
              .difficulty -
            b.blueprint
              .difficulty
          );
        }

        return (
          a.id.localeCompare(
            b.id
          )
        );
      }
    );

  if (
    ordered.length ===
    1
  ) {
    return (
      ordered[0] ??
      null
    );
  }

  const currentIndex =
    lastCompletedActivityId
      ? ordered.findIndex(
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
      ordered[0] ??
      null
    );
  }

  const nextIndex =
    (
      currentIndex +
      1
    ) %
    ordered.length;

  return (
    ordered[nextIndex] ??
    ordered[0] ??
    null
  );
}