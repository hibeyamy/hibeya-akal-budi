import {
  warnaMerah001
} from "@akal-budi/content-library";


export interface ActivityImplementation {
  implementationKey: string;

  activity: typeof warnaMerah001;
}


const implementations:
  readonly ActivityImplementation[] = [

    {
      implementationKey:
        "colour-choice-v1",

      activity:
        warnaMerah001
    }

  ];


export function getActivityImplementation(
  implementationKey: string
): ActivityImplementation | null {

  return (
    implementations.find(
      (implementation) =>
        implementation
          .implementationKey ===
        implementationKey
    ) ?? null
  );
}


export function hasActivityImplementation(
  implementationKey: string
): boolean {

  return implementations.some(
    (implementation) =>
      implementation
        .implementationKey ===
      implementationKey
  );
}
