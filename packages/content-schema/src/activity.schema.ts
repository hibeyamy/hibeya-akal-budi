import { z } from "zod";

export const AgeBandSchema = z.enum([
  "2-3",
  "3-4",
  "4-5",
  "5-6"
]);

export const LearningDomainSchema = z.enum([
  "numeracy",
  "language",
  "memory",
  "logic",
  "social",
  "life-skill"
]);

export const LocalisedTextSchema = z.object({
  ms: z.string().min(1),
  en: z.string().min(1)
});

export const ActivityOptionSchema = z.object({
  id: z.string().min(1),
  asset: z.string().min(1),
  correct: z.boolean()
});

export const InteractionModeSchema = z.enum([
  "independent",
  "co-play",
  "parent-guided"
]);

export const SensoryLoadSchema = z.enum([
  "low",
  "moderate"
]);

export const MalaysiaRelevanceSchema = z.enum([
  "core",
  "supporting",
  "neutral"
]);

export const ProvenanceTypeSchema = z.enum([
  "original",
  "commissioned",
  "licensed",
  "public-domain",
  "ai-assisted"
]);

export const DevelopmentSchema = z.object({
  objectiveIds: z.array(
    z.string().min(1)
  ).min(1),

  rationale: LocalisedTextSchema,

  interactionMode: InteractionModeSchema,

  estimatedMinutes: z
    .number()
    .int()
    .min(1)
    .max(15),

  parentParticipationRecommended:
    z.boolean(),

  offlineExtension:
    LocalisedTextSchema.optional(),

  researchRefs: z.array(
    z.string().min(1)
  ).default([])
});

export const WellbeingSchema = z.object({
  sensoryLoad: SensoryLoadSchema,

  rewardIntensity: z
    .number()
    .int()
    .min(0)
    .max(3),

  animationIntensity: z
    .number()
    .int()
    .min(0)
    .max(2),

  audioIntensity: z
    .number()
    .int()
    .min(0)
    .max(2),

  usesCountdownPressure:
    z.literal(false),

  usesLossAversion:
    z.literal(false),

  usesStreakPressure:
    z.literal(false),

  usesInfinitePlay:
    z.literal(false),

  usesBehaviouralAds:
    z.literal(false),

  penalisesMistakes:
    z.literal(false)
});

export const MalaysiaContextSchema = z.object({
  relevance: MalaysiaRelevanceSchema,

  elements: z.array(
    z.string().min(1)
  ),

  culturalReviewRequired:
    z.boolean()
}).superRefine(
  (context, validationContext) => {
    if (
      context.relevance !== "neutral" &&
      context.elements.length === 0
    ) {
      validationContext.addIssue({
        code: "custom",
        path: ["elements"],
        message:
          "Malaysian-context activities must identify at least one Malaysian element."
      });
    }
  }
);

export const AccessibilitySchema = z.object({
  reducedMotionSafe:
    z.literal(true),

  requiresReading:
    z.boolean(),

  requiresAudio:
    z.boolean(),

  colourIsLearningTarget:
    z.boolean(),

  largeTouchTargets:
    z.literal(true),

  alternativeInstructionAvailable:
    z.boolean()
});

export const ProvenanceSchema = z.object({
  type: ProvenanceTypeSchema,

  creator: z.string().min(1),

  assetSourceRefs: z.array(
    z.string().min(1)
  ).default([]),

  licenceRef:
    z.string()
      .min(1)
      .optional(),

  originalityReviewed:
    z.literal(true),

  culturalReviewed:
    z.boolean(),

  reviewedBy:
    z.string().min(1),

  reviewedAt:
    z.string().datetime()
}).superRefine(
  (provenance, validationContext) => {
    if (
      provenance.type === "licensed" &&
      !provenance.licenceRef
    ) {
      validationContext.addIssue({
        code: "custom",
        path: ["licenceRef"],
        message:
          "Licensed content requires a licence reference."
      });
    }
  }
);

export const ActivitySchema = z.object({
  id: z.string().min(1),

  version: z
    .number()
    .int()
    .positive(),

  mechanic: z.string().min(1),

  ageBand: AgeBandSchema,

  domains: z.array(
    LearningDomainSchema
  ).min(1),

  skills: z.array(
    z.string().min(1)
  ).min(1),

  difficulty: z
    .number()
    .int()
    .min(1)
    .max(5),

  title: LocalisedTextSchema,

  instruction: LocalisedTextSchema,

  options: z.array(
    ActivityOptionSchema
  ).min(2),

  development:
    DevelopmentSchema,

  wellbeing:
    WellbeingSchema,

  malaysia:
    MalaysiaContextSchema,

  accessibility:
    AccessibilitySchema,

  provenance:
    ProvenanceSchema,

  metadata: z.object({
    estimatedSeconds: z
      .number()
      .int()
      .positive(),

    active: z
      .boolean()
      .default(true)
  })
});

export type ActivityContent =
  z.infer<typeof ActivitySchema>;
  