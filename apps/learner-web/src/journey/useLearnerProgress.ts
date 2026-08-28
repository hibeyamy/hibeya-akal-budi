import {
  useCallback,
  useEffect,
  useState
} from "react";

import {
  getPlayableActivitiesForAgeBand
} from "@akal-budi/content-library";

import {
  getCachedLearnerRuntimeProfile,
  getLearnerJourneyState
} from "@akal-budi/offline";

import {
  calculateLearnerProgressPercent
} from "./learnerProgress";

export function useLearnerProgress() {
  const [
    progressPercent,
    setProgressPercent
  ] =
    useState(0);

  const refreshProgress =
    useCallback(
      async () => {
        const [
          journey,
          profile
        ] =
          await Promise.all([
            getLearnerJourneyState(),
            getCachedLearnerRuntimeProfile()
          ]);

        if (!profile) {
          setProgressPercent(
            0
          );

          return;
        }

        const playable =
          getPlayableActivitiesForAgeBand(
            profile.ageBand
          );

        setProgressPercent(
          calculateLearnerProgressPercent({
            completedActivityIds:
              journey.completedActivityIds,

            playableActivityIds:
              playable.map(
                activity =>
                  activity.id
              )
          })
        );
      },
      []
    );

  useEffect(
    () => {
      void refreshProgress();

      const refreshOnFocus = () => {
        void refreshProgress();
      };

      const refreshOnVisibility = () => {
        if (document.visibilityState === "visible") {
          void refreshProgress();
        }
      };

      window.addEventListener("focus", refreshOnFocus);
      document.addEventListener("visibilitychange", refreshOnVisibility);

      return () => {
        window.removeEventListener("focus", refreshOnFocus);
        document.removeEventListener("visibilitychange", refreshOnVisibility);
      };
    },
    [
      refreshProgress
    ]
  );

  return {
    progressPercent,
    refreshProgress
  };
}
