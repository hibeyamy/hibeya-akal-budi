import {
  useEffect,
  useState
} from "react";

import {
  clearLearnerJourneyState,
  saveLearnerRuntimeProfile
} from "../../../packages/offline/src";

import {
  LearnerJourneyScreen
} from "../../learner-web/src/journey";

export default {
  title:
    "Learner/Journey"
};

function DeterministicLearnerJourneyFixture() {
  const [
    ready,
    setReady
  ] =
    useState(false);

  useEffect(
    () => {
      let mounted =
        true;

      void (
        async () => {
          await clearLearnerJourneyState();

          await saveLearnerRuntimeProfile({
            childId:
              "storybook-child",

            ageBand:
              "3-4",

            preferredLanguage:
              "ms",

            validatedAt:
              1
          });

          if (
            mounted
          ) {
            setReady(
              true
            );
          }
        }
      )();

      return () => {
        mounted =
          false;
      };
    },
    []
  );

  if (
    !ready
  ) {
    return (
      <main
        aria-busy="true"
        className="p-6"
      >
        Menyediakan profil pembelajaran...
      </main>
    );
  }

  return (
    <LearnerJourneyScreen />
  );
}

export function Default() {
  return (
    <DeterministicLearnerJourneyFixture />
  );
}
