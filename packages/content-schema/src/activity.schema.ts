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

export const ActivitySchema = z.object({
  id: z.string().min(1),
  version: z.number().int().positive(),
  mechanic: z.string().min(1),
  ageBand: AgeBandSchema,
  domains: z.array(LearningDomainSchema).min(1),
  skills: z.array(z.string().min(1)).min(1),
  difficulty: z.number().int().min(1).max(5),

  title: LocalisedTextSchema,
  instruction: LocalisedTextSchema,

  options: z.array(ActivityOptionSchema).min(2),

  metadata: z.object({
    estimatedSeconds: z.number().int().positive(),
    active: z.boolean().default(true)
  })
});

export type ActivityContent = z.infer<typeof ActivitySchema>;
