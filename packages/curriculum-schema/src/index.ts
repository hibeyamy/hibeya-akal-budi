import {
  z
} from "zod";


export const CurriculumStatusSchema =
  z.enum([
    "draft",
    "source-verified",
    "mapped",
    "educator-reviewed",
    "approved",
    "published",
    "superseded"
  ]);


export type CurriculumStatus =
  z.infer<
    typeof CurriculumStatusSchema
  >;


export const CurriculumAuthoritySchema =
  z.object({
    id:
      z.string().min(1),

    name:
      z.string().min(1),

    countryCode:
      z.string()
        .length(2)
        .transform(
          value =>
            value.toUpperCase()
        )
  });


export type CurriculumAuthority =
  z.infer<
    typeof CurriculumAuthoritySchema
  >;


export const CurriculumVersionSchema =
  z.object({
    id:
      z.string().min(1),

    authorityId:
      z.string().min(1),

    frameworkId:
      z.string().min(1),

    edition:
      z.string().min(1),

    effectiveFrom:
      z.string().datetime(),

    effectiveTo:
      z.string()
        .datetime()
        .nullable()
        .default(
          null
        ),

    status:
      CurriculumStatusSchema,

    sourceIds:
      z.array(
        z.string().min(1)
      )
  });


export type CurriculumVersion =
  z.infer<
    typeof CurriculumVersionSchema
  >;


export const EducationLevelSchema =
  z.object({
    id:
      z.string().min(1),

    label:
      z.object({
        ms:
          z.string().min(1),

        en:
          z.string().min(1)
      }),

    order:
      z.number()
        .int()
        .nonnegative()
  });


export type EducationLevel =
  z.infer<
    typeof EducationLevelSchema
  >;


export const SubjectSchema =
  z.object({
    id:
      z.string().min(1),

    label:
      z.object({
        ms:
          z.string().min(1),

        en:
          z.string().min(1)
      })
  });


export type Subject =
  z.infer<
    typeof SubjectSchema
  >;


export const StrandSchema =
  z.object({
    id:
      z.string().min(1),

    subjectId:
      z.string().min(1),

    label:
      z.object({
        ms:
          z.string().min(1),

        en:
          z.string().min(1)
      })
  });


export type Strand =
  z.infer<
    typeof StrandSchema
  >;


export const CurriculumStandardSchema =
  z.object({
    id:
      z.string().min(1),

    curriculumVersionId:
      z.string().min(1),

    levelId:
      z.string().min(1),

    subjectId:
      z.string().min(1),

    strandId:
      z.string()
        .min(1)
        .nullable(),

    parentStandardId:
      z.string()
        .min(1)
        .nullable(),

    code:
      z.string().min(1),

    type:
      z.enum([
        "content-standard",
        "learning-standard",
        "other"
      ]),

    description:
      z.object({
        ms:
          z.string().min(1),

        en:
          z.string()
            .min(1)
            .nullable()
      }),

    status:
      CurriculumStatusSchema
  });


export type CurriculumStandard =
  z.infer<
    typeof CurriculumStandardSchema
  >;


export const SkillSchema =
  z.object({
    id:
      z.string()
        .min(1)
        .regex(
          /^[a-z0-9][a-z0-9-]*$/
        ),

    label:
      z.object({
        ms:
          z.string().min(1),

        en:
          z.string().min(1)
      }),

    description:
      z.object({
        ms:
          z.string().min(1),

        en:
          z.string().min(1)
      }),

    domain:
      z.string().min(1),

    active:
      z.boolean()
  });


export type Skill =
  z.infer<
    typeof SkillSchema
  >;


export const SkillPrerequisiteSchema =
  z.object({
    skillId:
      z.string().min(1),

    prerequisiteSkillId:
      z.string().min(1),

    strength:
      z.enum([
        "required",
        "recommended"
      ])
  })
  .refine(
    value =>
      value.skillId !==
      value.prerequisiteSkillId,
    {
      message:
        "A skill cannot require itself."
    }
  );


export type SkillPrerequisite =
  z.infer<
    typeof SkillPrerequisiteSchema
  >;


export const ActivitySkillMappingSchema =
  z.object({
    skillId:
      z.string().min(1),

    role:
      z.enum([
        "primary",
        "supporting"
      ]),

    weight:
      z.number()
        .positive()
        .max(1)
  });


export type ActivitySkillMapping =
  z.infer<
    typeof ActivitySkillMappingSchema
  >;


export const ActivityCurriculumMappingSchema =
  z.object({
    curriculumVersionId:
      z.string().min(1),

    standardId:
      z.string().min(1),

    alignment:
      z.enum([
        "direct",
        "supporting"
      ]),

    reviewStatus:
      z.enum([
        "draft",
        "verified"
      ]),

    reviewedBy:
      z.string()
        .min(1)
        .nullable(),

    reviewedAt:
      z.string()
        .datetime()
        .nullable()
  });


export type ActivityCurriculumMapping =
  z.infer<
    typeof ActivityCurriculumMappingSchema
  >;


export const CurriculumSourceSchema =
  z.object({
    id:
      z.string().min(1),

    authorityId:
      z.string().min(1),

    title:
      z.string().min(1),

    edition:
      z.string()
        .min(1)
        .nullable(),

    effectiveDate:
      z.string()
        .datetime()
        .nullable(),

    sourceUrl:
      z.string().url(),

    retrievedAt:
      z.string().datetime(),

    sha256:
      z.string()
        .regex(
          /^[a-f0-9]{64}$/
        ),

    reviewStatus:
      z.enum([
        "unverified",
        "verified"
      ])
  });


export type CurriculumSource =
  z.infer<
    typeof CurriculumSourceSchema
  >;


export const CurriculumPackSchema =
  z.object({
    id:
      z.string().min(1),

    authority:
      CurriculumAuthoritySchema,

    version:
      CurriculumVersionSchema,

    levels:
      z.array(
        EducationLevelSchema
      ),

    subjects:
      z.array(
        SubjectSchema
      ),

    strands:
      z.array(
        StrandSchema
      ),

    standards:
      z.array(
        CurriculumStandardSchema
      ),

    sources:
      z.array(
        CurriculumSourceSchema
      )
  });


export type CurriculumPack =
  z.infer<
    typeof CurriculumPackSchema
  >;
