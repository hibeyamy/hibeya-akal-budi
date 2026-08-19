import type {
  AgeBandProfile
} from "./types";


export const ageBandProfiles:
  readonly AgeBandProfile[] = [

    {
      ageBand:
        "2-3",

      curriculumPosition:
        "developmentally-informed",

      recommendedSessionMinutes: {
        min: 2,
        max: 4
      },

      maxChoicesPerScreen:
        2,

      maxInstructionSteps:
        1,

      preferredMechanics: [
        "tap-choice",
        "matching",
        "listen-choose"
      ],

      designPrinciples: [
        "One simple goal per activity.",
        "Large touch targets.",
        "Minimal text.",
        "Adult co-play encouraged.",
        "Avoid timers and speed pressure.",
        "Use familiar real-world objects."
      ]
    },


    {
      ageBand:
        "3-4",

      curriculumPosition:
        "developmentally-informed",

      recommendedSessionMinutes: {
        min: 3,
        max: 5
      },

      maxChoicesPerScreen:
        3,

      maxInstructionSteps:
        1,

      preferredMechanics: [
        "tap-choice",
        "matching",
        "sorting",
        "drag-place",
        "listen-choose"
      ],

      designPrinciples: [
        "Short repeated patterns.",
        "Concrete concepts before symbols.",
        "No negative failure language.",
        "Encourage verbal naming with an adult.",
        "Keep visual scenes uncluttered."
      ]
    },


    {
      ageBand:
        "4-5",

      curriculumPosition:
        "preschool-curriculum-mappable",

      recommendedSessionMinutes: {
        min: 4,
        max: 7
      },

      maxChoicesPerScreen:
        4,

      maxInstructionSteps:
        2,

      preferredMechanics: [
        "tap-choice",
        "matching",
        "sorting",
        "sequence",
        "drag-place",
        "trace",
        "listen-choose"
      ],

      designPrinciples: [
        "Introduce simple reasoning.",
        "Use language-rich instructions.",
        "Allow more than one valid strategy where appropriate.",
        "Connect screen activities with everyday life.",
        "No ranking against other children."
      ]
    },


    {
      ageBand:
        "5-6",

      curriculumPosition:
        "preschool-curriculum-mappable",

      recommendedSessionMinutes: {
        min: 5,
        max: 8
      },

      maxChoicesPerScreen:
        5,

      maxInstructionSteps:
        2,

      preferredMechanics: [
        "tap-choice",
        "matching",
        "sorting",
        "sequence",
        "drag-place",
        "trace",
        "listen-choose",
        "spot-difference"
      ],

      designPrinciples: [
        "Include simple problem-solving.",
        "Support early literacy and numeracy without over-schooling.",
        "Use meaningful Malaysian contexts.",
        "Encourage explanation and conversation.",
        "Keep sessions finite and easy to stop."
      ]
    }

  ];
  