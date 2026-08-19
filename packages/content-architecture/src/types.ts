export type AgeBand =
  | "2-3"
  | "3-4"
  | "4-5"
  | "5-6";


export type CurriculumPosition =
  | "developmentally-informed"
  | "preschool-curriculum-mappable";


export type ContentDomain =
  | "language"
  | "early-numeracy"
  | "thinking"
  | "visual-perception"
  | "fine-motor"
  | "world-around-us"
  | "social-emotional"
  | "values"
  | "creativity";


export type InteractionMechanic =
  | "tap-choice"
  | "matching"
  | "sorting"
  | "sequence"
  | "drag-place"
  | "trace"
  | "listen-choose"
  | "spot-difference";


export type SessionIntensity =
  | "very-light"
  | "light"
  | "moderate";


export interface AgeBandProfile {
  ageBand: AgeBand;

  curriculumPosition:
    CurriculumPosition;

  recommendedSessionMinutes: {
    min: number;
    max: number;
  };

  maxChoicesPerScreen: number;

  maxInstructionSteps: number;

  preferredMechanics:
    readonly InteractionMechanic[];

  designPrinciples:
    readonly string[];
}


export interface ContentTheme {
  id: string;

  titleMs: string;

  titleEn: string;

  malaysiaElements:
    readonly string[];

  suitableAgeBands:
    readonly AgeBand[];

  domains:
    readonly ContentDomain[];
}


export interface ActivityBlueprint {
  id: string;

  titleMs: string;

  titleEn: string;

  ageBands:
    readonly AgeBand[];

  domains:
    readonly ContentDomain[];

  mechanic:
    InteractionMechanic;

  themeId: string;

  learningObjectiveIds:
    readonly string[];

  difficulty: 1 | 2 | 3 | 4 | 5;

  intensity:
    SessionIntensity;

  targetDurationSeconds: {
    min: number;
    max: number;
  };

  malaysiaElements:
    readonly string[];

  originalityNote: string;

  healthyUseNote: string;
}
