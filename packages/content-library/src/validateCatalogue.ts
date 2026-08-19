import {
  activityBlueprints
} from "@akal-budi/content-architecture";

import {
  playableActivities
} from "./catalogue";


export interface CatalogueIssue {
  activityId: string;

  message: string;
}


export function validatePlayableCatalogue():
  CatalogueIssue[] {

  const issues:
    CatalogueIssue[] = [];


  const ids =
    new Set<string>();


  for (
    const activity
    of playableActivities
  ) {

    if (
      ids.has(
        activity.id
      )
    ) {
      issues.push({
        activityId:
          activity.id,

        message:
          "Duplicate playable activity id."
      });
    }


    ids.add(
      activity.id
    );


    const blueprint =
      activityBlueprints.find(
        (item) =>
          item.id ===
          activity.blueprintId
      );


    if (!blueprint) {
      issues.push({
        activityId:
          activity.id,

        message:
          `Unknown blueprint: ${activity.blueprintId}`
      });

      continue;
    }


    if (
      activity.version < 1
    ) {
      issues.push({
        activityId:
          activity.id,

        message:
          "Activity version must be at least 1."
      });
    }


    if (
      activity
        .implementationKey
        .trim()
        .length === 0
    ) {
      issues.push({
        activityId:
          activity.id,

        message:
          "Activity has no implementation key."
      });
    }


    for (
      const ageBand
      of activity.ageBands
    ) {
      if (
        !blueprint
          .ageBands
          .includes(
            ageBand
          )
      ) {
        issues.push({
          activityId:
            activity.id,

          message:
            `Playable age band ${ageBand} is not allowed by blueprint ${blueprint.id}.`
        });
      }
    }
  }


  return issues;
}
