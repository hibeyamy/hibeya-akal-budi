import {
  ageBandProfiles
} from "./ageBands";

import {
  activityBlueprints
} from "./blueprints";

import {
  contentThemes
} from "./themes";


export interface ContentArchitectureIssue {
  blueprintId: string;

  message: string;
}


export function validateContentArchitecture():
  ContentArchitectureIssue[] {

  const issues:
    ContentArchitectureIssue[] = [];


  for (
    const blueprint
    of activityBlueprints
  ) {
    const theme =
      contentThemes.find(
        (item) =>
          item.id ===
          blueprint.themeId
      );


    if (!theme) {
      issues.push({
        blueprintId:
          blueprint.id,

        message:
          `Unknown theme: ${blueprint.themeId}`
      });

      continue;
    }


    for (
      const ageBand
      of blueprint.ageBands
    ) {
      const profile =
        ageBandProfiles.find(
          (item) =>
            item.ageBand ===
            ageBand
        );


      if (!profile) {
        issues.push({
          blueprintId:
            blueprint.id,

          message:
            `Unknown age band: ${ageBand}`
        });

        continue;
      }


      if (
        !profile
          .preferredMechanics
          .includes(
            blueprint.mechanic
          )
      ) {
        issues.push({
          blueprintId:
            blueprint.id,

          message:
            `${blueprint.mechanic} is not preferred for ${ageBand}`
        });
      }


      if (
        !theme
          .suitableAgeBands
          .includes(
            ageBand
          )
      ) {
        issues.push({
          blueprintId:
            blueprint.id,

          message:
            `Theme ${theme.id} is not suitable for ${ageBand}`
        });
      }


      if (
        blueprint
          .targetDurationSeconds
          .max >
        profile
          .recommendedSessionMinutes
          .max *
          60
      ) {
        issues.push({
          blueprintId:
            blueprint.id,

          message:
            `Activity exceeds recommended session length for ${ageBand}`
        });
      }
    }


    if (
      blueprint
        .malaysiaElements
        .length === 0
    ) {
      issues.push({
        blueprintId:
          blueprint.id,

        message:
          "Blueprint has no Malaysian context."
      });
    }


    if (
      blueprint
        .originalityNote
        .trim()
        .length < 20
    ) {
      issues.push({
        blueprintId:
          blueprint.id,

        message:
          "Originality note is insufficient."
      });
    }


    if (
      blueprint
        .healthyUseNote
        .trim()
        .length < 20
    ) {
      issues.push({
        blueprintId:
          blueprint.id,

        message:
          "Healthy-use note is insufficient."
      });
    }
  }


  return issues;
}
