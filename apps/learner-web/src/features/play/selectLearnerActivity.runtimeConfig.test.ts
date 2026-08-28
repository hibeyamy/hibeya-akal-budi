import {
  afterEach,
  describe,
  expect,
  it,
  vi
} from "vitest";


describe(
  "selectLearnerActivity runtime config boundary",
  () => {
    afterEach(
      () => {
        vi.resetModules();
        vi.unstubAllEnvs();
      }
    );


    it(
      "keeps missing runtime config on legacy authority",
      async () => {
        vi.stubEnv(
          "VITE_HIBEYA_ADAPTIVE_ENABLED",
          ""
        );

        vi.stubEnv(
          "VITE_HIBEYA_ADAPTIVE_ROLLOUT_PERCENT",
          ""
        );

        const {
          selectLearnerActivity
        } =
          await import(
            "./selectLearnerActivity"
          );

        const selected =
          selectLearnerActivity({
            childId:
              "child-runtime-config-test",
            ageBand:
              "3-4",
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            masteredSkillIds:
              [],
            skillProgress:
              []
          });

        expect(
          selected
        ).not.toBeNull();
      }
    );


    it(
      "keeps malformed runtime config on legacy authority",
      async () => {
        vi.stubEnv(
          "VITE_HIBEYA_ADAPTIVE_ENABLED",
          "true"
        );

        vi.stubEnv(
          "VITE_HIBEYA_ADAPTIVE_ROLLOUT_PERCENT",
          "999"
        );

        const {
          selectLearnerActivity
        } =
          await import(
            "./selectLearnerActivity"
          );

        const selected =
          selectLearnerActivity({
            childId:
              "child-runtime-config-test",
            ageBand:
              "3-4",
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            masteredSkillIds:
              [],
            skillProgress:
              []
          });

        expect(
          selected
        ).not.toBeNull();
      }
    );
  }
);
