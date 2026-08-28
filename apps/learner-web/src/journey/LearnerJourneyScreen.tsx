import {
  LearnerHome,
  LearnerRuntimeShell
} from "../shell";

import {
  LearnerActivityBridge
} from "./LearnerActivityBridge";

import {
  LearnerExplore
} from "./LearnerExplore";

import {
  useLearnerJourney
} from "./useLearnerJourney";

import {
  useLearnerProgress
} from "./useLearnerProgress";

import {
  useNextLearnerActivity
} from "./useNextLearnerActivity";

export function LearnerJourneyScreen() {
  const {
    state,
    goHome,
    goExplore,
    openActivity,
    closeActivity
  } =
    useLearnerJourney();

  const {
    openNextActivity
  } =
    useNextLearnerActivity({
      openActivity
    });

  const {
    progressPercent,
    refreshProgress
  } =
    useLearnerProgress();

  return (
    <LearnerRuntimeShell
      progressPercent={
        progressPercent
      }
    >
      {
        state.view ===
        "home"
          ? (
              <LearnerHome
                onContinue={
                  () =>
                    void openNextActivity()
                }
                onExplore={
                  goExplore
                }
              />
            )
          : null
      }

      {
        state.view ===
        "explore"
          ? (
              <LearnerExplore
                onBack={
                  goHome
                }
                onOpenActivity={
                  activityId =>
                    openActivity(
                      activityId,
                      "explore"
                    )
                }
              />
            )
          : null
      }

      {
        state.view ===
          "activity" &&
        state.activeActivityId
          ? (
              <LearnerActivityBridge
                activityId={
                  state.activeActivityId
                }
                onClose={
                  closeActivity
                }
                onComplete={
                  () =>
                    void refreshProgress()
                }
              />
            )
          : null
      }
    </LearnerRuntimeShell>
  );
}
