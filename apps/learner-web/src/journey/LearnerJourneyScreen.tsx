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
    openNextActivity,
    selectionError
  } =
    useNextLearnerActivity({
      openActivity
    });

  const {
    progressPercent,
    progressAvailable,
    playableActivities,
    refreshProgress
  } =
    useLearnerProgress();

  return (
    <LearnerRuntimeShell
      progressPercent={
        progressPercent
      }
      progressAvailable={
        progressAvailable
      }
    >
      {
        state.view ===
        "home"
          ? (
              <>
                <LearnerHome
                  contentAvailable={
                    progressAvailable
                  }
                  onContinue={
                    () =>
                      void openNextActivity()
                  }
                  onExplore={
                    goExplore
                  }
                />

                {
                  selectionError &&
                  progressAvailable
                    ? (
                        <p
                          role="alert"
                          className="mx-auto -mt-8 mb-8 max-w-3xl px-4 text-center font-semibold text-rose-700"
                        >
                          {selectionError}
                        </p>
                      )
                    : null
                }
              </>
            )
          : null
      }

      {
        state.view ===
        "explore"
          ? (
              <LearnerExplore
                activities={
                  playableActivities
                }
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
