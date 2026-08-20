import {
  warnaBungaRaya001,
  warnaMerah001
} from "@akal-budi/content-library";


type SupportedActivity =
  typeof warnaMerah001;


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
        "warna-merah-001",

      implementationKey:
        "colour-choice-v1",

      activity:
        warnaMerah001
    },


    {
      activityId:
        "warna-bunga-raya-001",

      implementationKey:
        "colour-choice-v1",

      activity:
        warnaBungaRaya001
    }

  ];


export function getActivityImplementation(
  activityId: string,
  implementationKey: string
): ActivityImplementation | null {

  return (
    implementations.find(
      (implementation) =>
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
    (implementation) =>
      implementation
        .activityId ===
        activityId &&
      implementation
        .implementationKey ===
        implementationKey
  );
}
