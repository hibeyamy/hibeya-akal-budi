import {
  activityBlueprints,
  type AgeBand,
  type ActivityBlueprint
} from "@akal-budi/content-architecture";


export interface PlayableActivity {
  id: string;

  blueprintId: string;

  version: number;

  enabled: boolean;

  ageBands:
    readonly AgeBand[];

  titleMs: string;

  titleEn: string;

  implementationKey:
    string;
}


export interface ResolvedPlayableActivity
  extends PlayableActivity {
  blueprint:
    ActivityBlueprint;
}


export const playableActivities:
  readonly PlayableActivity[] = [

    {
      id:
        "warna-bunga-raya-001",

      blueprintId:
        "warna-bunga-raya",

      version:
        1,

      enabled:
        true,

      ageBands:
        [
          "3-4"
        ],

      titleMs:
        "Mana Bunga Raya Merah?",

      titleEn:
        "Which Hibiscus Is Red?",

      implementationKey:
        "colour-choice-v1"
    },

    {
      id:
        "warna-merah-001",

      blueprintId:
        "warna-bunga-raya",

      version:
        2,

      enabled:
        true,

      ageBands:
        [
          "3-4"
        ],

      titleMs:
        "Cari Warna Merah",

      titleEn:
        "Find the Red Colour",

      implementationKey:
        "colour-choice-v1"
    }

  ];


export function getPlayableActivity(
  activityId: string
): ResolvedPlayableActivity | null {

  const activity =
    playableActivities.find(
      item =>
        item.id ===
        activityId
    );


  if (!activity) {
    return null;
  }


  const blueprint =
    activityBlueprints.find(
      item =>
        item.id ===
        activity.blueprintId
    );


  if (!blueprint) {
    return null;
  }


  return {
    ...activity,
    blueprint
  };
}


export function getPlayableActivitiesForAgeBand(
  ageBand: AgeBand
): ResolvedPlayableActivity[] {

  return playableActivities
    .filter(
      activity =>
        activity.enabled &&
        activity
          .ageBands
          .includes(
            ageBand
          )
    )
    .map(
      activity =>
        getPlayableActivity(
          activity.id
        )
    )
    .filter(
      (
        activity
      ): activity is ResolvedPlayableActivity =>
        activity !==
        null
    );
}
