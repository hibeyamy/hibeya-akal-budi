import {
  describe,
  expect,
  it
} from "vitest";

import {
  ActivityCurriculumMappingSchema,
  ActivitySkillMappingSchema,
  SkillPrerequisiteSchema,
  SkillSchema
} from "../index";


describe(
  "curriculum schema",
  () => {

    it(
      "accepts a valid generic skill",
      () => {

        const skill =
          SkillSchema.parse({
            id:
              "colour-recognition",

            label: {
              ms:
                "Pengecaman warna",

              en:
                "Colour recognition"
            },

            description: {
              ms:
                "Mengenal dan membezakan warna.",

              en:
                "Recognise and distinguish colours."
            },

            domain:
              "visual-cognition",

            active:
              true
          });


        expect(
          skill.id
        ).toBe(
          "colour-recognition"
        );
      }
    );


    it(
      "rejects a self prerequisite",
      () => {

        expect(
          () =>
            SkillPrerequisiteSchema.parse({
              skillId:
                "colour-recognition",

              prerequisiteSkillId:
                "colour-recognition",

              strength:
                "required"
            })
        ).toThrow();
      }
    );


    it(
      "supports weighted activity skill mappings",
      () => {

        expect(
          ActivitySkillMappingSchema.parse({
            skillId:
              "colour-recognition",

            role:
              "primary",

            weight:
              1
          })
        ).toEqual({
          skillId:
            "colour-recognition",

          role:
            "primary",

          weight:
            1
        });
      }
    );


    it(
      "keeps curriculum mappings reviewable",
      () => {

        expect(
          ActivityCurriculumMappingSchema.parse({
            curriculumVersionId:
              "example-version",

            standardId:
              "example-standard",

            alignment:
              "direct",

            reviewStatus:
              "draft",

            reviewedBy:
              null,

            reviewedAt:
              null
          })
        ).toMatchObject({
          reviewStatus:
            "draft"
        });
      }
    );

  }
);
