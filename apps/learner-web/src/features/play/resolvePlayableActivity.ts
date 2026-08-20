import {
  getPlayableActivity,
  type ResolvedPlayableActivity
} from "@akal-budi/content-library";

import {
  getActivityImplementation,
  type ActivityImplementation
} from "./activityRegistry";


export interface RuntimePlayableActivity {
  catalogue:
    ResolvedPlayableActivity;

  implementation:
    ActivityImplementation;
}


export function resolveRuntimeActivity(
  activityId: string
): RuntimePlayableActivity | null {

  const catalogue =
    getPlayableActivity(
      activityId
    );


  if (!catalogue) {
    return null;
  }


  const implementation =
    getActivityImplementation(
      catalogue.id,
      catalogue
        .implementationKey
    );


  if (!implementation) {
    return null;
  }


  return {
    catalogue,
    implementation
  };
}
