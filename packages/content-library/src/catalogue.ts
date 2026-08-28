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

  sequence: number;

  difficulty: number;

  skillIds:
    readonly string[];

  skillMappings:
    readonly {
      skillId: string;
      role:
        "primary" |
        "supporting";
      weight: number;
    }[];

  primarySkillIds:
    readonly string[];

  requiredPrerequisiteSkillIds:
    readonly string[];

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
        "beza-buah-001",

      blueprintId:
        "warna-bunga-raya",

      version:
        1,

      enabled:
        true,

      sequence:
        40,

      difficulty:
        1,

      skillIds:
        [
          "visual-discrimination",
          "colour-recognition"
        ],

      skillMappings:
        [
          {
            "skillId": "visual-discrimination",
            "role": "primary",
            "weight": 1
          },
          {
            "skillId": "colour-recognition",
            "role": "supporting",
            "weight": 0.25
          }
        ],

      primarySkillIds:
        [
          "visual-discrimination"
        ],

      requiredPrerequisiteSkillIds:
        [],

      ageBands:
        [
          "3-4"
        ],

      titleMs:
        "Buah Mana Berbeza?",

      titleEn:
        "Which Fruit Is Different?",

      implementationKey:
        "colour-choice-v1"
    },

    {
      id:
        "beza-bunga-raya-001",

      blueprintId:
        "warna-bunga-raya",

      version:
        1,

      enabled:
        true,

      sequence:
        30,

      difficulty:
        1,

      skillIds:
        [
          "visual-discrimination",
          "colour-recognition"
        ],

      skillMappings:
        [
          {
            "skillId": "visual-discrimination",
            "role": "primary",
            "weight": 1
          },
          {
            "skillId": "colour-recognition",
            "role": "supporting",
            "weight": 0.25
          }
        ],

      primarySkillIds:
        [
          "visual-discrimination"
        ],

      requiredPrerequisiteSkillIds:
        [],

      ageBands:
        [
          "3-4"
        ],

      titleMs:
        "Yang Mana Berbeza?",

      titleEn:
        "Which One Is Different?",

      implementationKey:
        "colour-choice-v1"
    },

    {
      id:
        "beza-epal-001",

      blueprintId:
        "warna-bunga-raya",

      version:
        1,

      enabled:
        true,

      sequence:
        50,

      difficulty:
        2,

      skillIds:
        [
          "visual-discrimination",
          "colour-recognition"
        ],

      skillMappings:
        [
          {
            "skillId": "visual-discrimination",
            "role": "primary",
            "weight": 1
          },
          {
            "skillId": "colour-recognition",
            "role": "supporting",
            "weight": 0.25
          }
        ],

      primarySkillIds:
        [
          "visual-discrimination"
        ],

      requiredPrerequisiteSkillIds:
        [],

      ageBands:
        [
          "3-4"
        ],

      titleMs:
        "Epal Mana Berbeza?",

      titleEn:
        "Which Apple Is Different?",

      implementationKey:
        "colour-choice-v1"
    },

    {
      id:
        "kuantiti-lebih-001",

      blueprintId:
        "warna-bunga-raya",

      version:
        1,

      enabled:
        true,

      sequence:
        103,

      difficulty:
        2,

      skillIds:
        [
          "early-numeracy"
        ],

      skillMappings:
        [
          {
            "role": "primary",
            "skillId": "early-numeracy",
            "weight": 1
          }
        ],

      primarySkillIds:
        [
          "early-numeracy"
        ],

      requiredPrerequisiteSkillIds:
        [],

      ageBands:
        [
          "3-4"
        ],

      titleMs:
        "Buah Mana Berbeza?",

      titleEn:
        "Which Fruit Is Different?",

      implementationKey:
        "colour-choice-v1"
    },

    {
      id:
        "nombor-dua-001",

      blueprintId:
        "warna-bunga-raya",

      version:
        1,

      enabled:
        true,

      sequence:
        102,

      difficulty:
        1,

      skillIds:
        [
          "early-numeracy"
        ],

      skillMappings:
        [
          {
            "role": "primary",
            "skillId": "early-numeracy",
            "weight": 1
          }
        ],

      primarySkillIds:
        [
          "early-numeracy"
        ],

      requiredPrerequisiteSkillIds:
        [],

      ageBands:
        [
          "3-4"
        ],

      titleMs:
        "Buah Mana Berbeza?",

      titleEn:
        "Which Fruit Is Different?",

      implementationKey:
        "colour-choice-v1"
    },

    {
      id:
        "nombor-satu-001",

      blueprintId:
        "warna-bunga-raya",

      version:
        1,

      enabled:
        true,

      sequence:
        101,

      difficulty:
        1,

      skillIds:
        [
          "early-numeracy"
        ],

      skillMappings:
        [
          {
            "role": "primary",
            "skillId": "early-numeracy",
            "weight": 1
          }
        ],

      primarySkillIds:
        [
          "early-numeracy"
        ],

      requiredPrerequisiteSkillIds:
        [],

      ageBands:
        [
          "3-4"
        ],

      titleMs:
        "Buah Mana Berbeza?",

      titleEn:
        "Which Fruit Is Different?",

      implementationKey:
        "colour-choice-v1"
    },

    {
      id:
        "warna-bunga-raya-001",

      blueprintId:
        "warna-bunga-raya",

      version:
        1,

      enabled:
        true,

      sequence:
        10,

      difficulty:
        1,

      skillIds:
        [
          "colour-recognition",
          "visual-discrimination"
        ],

      skillMappings:
        [
          {
            "skillId": "colour-recognition",
            "role": "primary",
            "weight": 1
          },
          {
            "skillId": "visual-discrimination",
            "role": "supporting",
            "weight": 0.5
          }
        ],

      primarySkillIds:
        [
          "colour-recognition"
        ],

      requiredPrerequisiteSkillIds:
        [],

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

      sequence:
        20,

      difficulty:
        1,

      skillIds:
        [
          "colour-recognition",
          "visual-discrimination"
        ],

      skillMappings:
        [
          {
            "skillId": "colour-recognition",
            "role": "primary",
            "weight": 1
          },
          {
            "skillId": "visual-discrimination",
            "role": "supporting",
            "weight": 0.5
          }
        ],

      primarySkillIds:
        [
          "colour-recognition"
        ],

      requiredPrerequisiteSkillIds:
        [],

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
    },

    {
      id:
        "warna-ungu-001",

      blueprintId:
        "warna-bunga-raya",

      version:
        1,

      enabled:
        true,

      sequence:
        60,

      difficulty:
        2,

      skillIds:
        [
          "colour-recognition",
          "visual-discrimination"
        ],

      skillMappings:
        [
          {
            "skillId": "colour-recognition",
            "role": "primary",
            "weight": 1
          },
          {
            "skillId": "visual-discrimination",
            "role": "supporting",
            "weight": 0.5
          }
        ],

      primarySkillIds:
        [
          "colour-recognition"
        ],

      requiredPrerequisiteSkillIds:
        [],

      ageBands:
        [
          "3-4"
        ],

      titleMs:
        "Cari Warna Ungu",

      titleEn:
        "Find Purple",

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
    .sort(
      (
        left,
        right
      ) =>
        left.sequence -
          right.sequence ||
        left.id.localeCompare(
          right.id
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
