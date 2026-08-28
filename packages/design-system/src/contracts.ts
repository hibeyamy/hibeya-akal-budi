export type Audience =
  | "learner"
  | "parent";


export interface AudienceDesignContract {
  audience:
    Audience;

  minimumTouchTargetPx:
    number;

  readingDensity:
    "very-low"
    | "low"
    | "normal";

  motion:
    "minimal"
    | "standard";

  visualComplexity:
    "low"
    | "moderate";

  destructiveActionsRequireConfirmation:
    boolean;
}


export const learnerDesignContract:
  AudienceDesignContract = {
    audience:
      "learner",

    minimumTouchTargetPx:
      56,

    readingDensity:
      "very-low",

    motion:
      "minimal",

    visualComplexity:
      "low",

    destructiveActionsRequireConfirmation:
      true
  };


export const parentDesignContract:
  AudienceDesignContract = {
    audience:
      "parent",

    minimumTouchTargetPx:
      44,

    readingDensity:
      "normal",

    motion:
      "standard",

    visualComplexity:
      "moderate",

    destructiveActionsRequireConfirmation:
      true
  };


export function getAudienceDesignContract(
  audience:
    Audience
): AudienceDesignContract {
  return audience ===
    "learner"
    ? learnerDesignContract
    : parentDesignContract;
}
