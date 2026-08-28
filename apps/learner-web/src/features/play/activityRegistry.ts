import {
  bezaBuah001,
  bezaBungaRaya001,
  bezaEpal001,
  kuantitiLebih001,
  nomborDua001,
  nomborSatu001,
  warnaBungaRaya001,
  warnaMerah001,
  warnaUngu001
} from "@akal-budi/content-library";


type SupportedActivity =
  typeof bezaBuah001 |
  typeof bezaBungaRaya001 |
  typeof bezaEpal001 |
  typeof kuantitiLebih001 |
  typeof nomborDua001 |
  typeof nomborSatu001 |
  typeof warnaBungaRaya001 |
  typeof warnaMerah001 |
  typeof warnaUngu001;


export interface ActivityImplementation {
  activityId: string;

  implementationKey:
    string;

  activity:
    SupportedActivity;
}


const implementations:
  readonly ActivityImplementation[] = [

    {
      activityId:
        "beza-buah-001",

      implementationKey:
        "colour-choice-v1",

      activity:
        bezaBuah001
    },

    {
      activityId:
        "beza-bunga-raya-001",

      implementationKey:
        "colour-choice-v1",

      activity:
        bezaBungaRaya001
    },

    {
      activityId:
        "beza-epal-001",

      implementationKey:
        "colour-choice-v1",

      activity:
        bezaEpal001
    },

    {
      activityId:
        "kuantiti-lebih-001",

      implementationKey:
        "colour-choice-v1",

      activity:
        kuantitiLebih001
    },

    {
      activityId:
        "nombor-dua-001",

      implementationKey:
        "colour-choice-v1",

      activity:
        nomborDua001
    },

    {
      activityId:
        "nombor-satu-001",

      implementationKey:
        "colour-choice-v1",

      activity:
        nomborSatu001
    },

    {
      activityId:
        "warna-bunga-raya-001",

      implementationKey:
        "colour-choice-v1",

      activity:
        warnaBungaRaya001
    },

    {
      activityId:
        "warna-merah-001",

      implementationKey:
        "colour-choice-v1",

      activity:
        warnaMerah001
    },

    {
      activityId:
        "warna-ungu-001",

      implementationKey:
        "colour-choice-v1",

      activity:
        warnaUngu001
    }

  ];


export function getActivityImplementation(
  activityId: string,
  implementationKey: string
): ActivityImplementation | null {

  return (
    implementations.find(
      implementation =>
        implementation
          .activityId ===
          activityId &&
        implementation
          .implementationKey ===
          implementationKey
    ) ??
    null
  );
}


export function hasActivityImplementation(
  activityId: string,
  implementationKey: string
): boolean {

  return implementations.some(
    implementation =>
      implementation
        .activityId ===
        activityId &&
      implementation
        .implementationKey ===
        implementationKey
  );
}
