export const colourTokens = {
  brand: {
    ink:
      "#1F2937",

    warm:
      "#B45309",

    soft:
      "#FFF7ED"
  },

  surface: {
    page:
      "#FFFDF8",

    card:
      "#FFFFFF",

    subtle:
      "#F8FAFC"
  },

  text: {
    primary:
      "#1F2937",

    secondary:
      "#475569",

    muted:
      "#64748B",

    inverse:
      "#FFFFFF"
  },

  feedback: {
    successSurface:
      "#ECFDF5",

    successText:
      "#065F46",

    gentleSurface:
      "#FFFBEB",

    gentleText:
      "#92400E",

    errorSurface:
      "#FEF2F2",

    errorText:
      "#991B1B"
  },

  focus: {
    ring:
      "#F59E0B"
  }
} as const;


export const spacingTokens = {
  xs:
    "0.25rem",

  sm:
    "0.5rem",

  md:
    "1rem",

  lg:
    "1.5rem",

  xl:
    "2rem",

  "2xl":
    "3rem"
} as const;


export const radiusTokens = {
  sm:
    "0.75rem",

  md:
    "1rem",

  lg:
    "1.5rem",

  xl:
    "2rem",

  round:
    "9999px"
} as const;


export const typographyTokens = {
  family: {
    ui:
      "system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
  },

  size: {
    xs:
      "0.75rem",

    sm:
      "0.875rem",

    base:
      "1rem",

    lg:
      "1.125rem",

    xl:
      "1.25rem",

    "2xl":
      "1.5rem",

    "3xl":
      "1.875rem",

    "4xl":
      "2.25rem"
  },

  weight: {
    regular:
      400,

    medium:
      500,

    semibold:
      600,

    bold:
      700
  },

  lineHeight: {
    compact:
      1.2,

    normal:
      1.5,

    relaxed:
      1.7
  }
} as const;


export const motionTokens = {
  duration: {
    instant:
      "0ms",

    quick:
      "120ms",

    gentle:
      "180ms"
  },

  easing: {
    standard:
      "cubic-bezier(0.2, 0, 0, 1)"
  }
} as const;


export const interactionTokens = {
  minTouchTargetPx:
    44,

  learnerPreferredTouchTargetPx:
    56,

  focusRingPx:
    4,

  learnerMaxChoicesPerRow:
    3
} as const;


export const wellbeingDesignRules = {
  flashingAllowed:
    false,

  autoPlayCelebrationAllowed:
    false,

  infiniteScrollAllowed:
    false,

  streakPressureAllowed:
    false,

  lossAversionAllowed:
    false,

  countdownPressureAllowed:
    false,

  reducedMotionRequired:
    true,

  gentleFeedbackRequired:
    true
} as const;


export const designTokens = {
  colour:
    colourTokens,

  spacing:
    spacingTokens,

  radius:
    radiusTokens,

  typography:
    typographyTokens,

  motion:
    motionTokens,

  interaction:
    interactionTokens,

  wellbeing:
    wellbeingDesignRules
} as const;


export type DesignTokens =
  typeof designTokens;
