import {
  useCallback,
  useEffect,
  useState
} from "react";

import {
  getCachedLearnerRuntimeProfile,
  getLearnerJourneyState
} from "@akal-budi/offline";

import type {
  ResolvedPlayableActivity
} from "@akal-budi/content-library";

import {
  calculateLearnerProgressPercent
} from "./learnerProgress";

import {
  getLearnerActivitiesForAgeBand
} from "./learnerActivityAvailability";

export function useLearnerProgress() {
  const [
    progressPercent,
    setProgressPercent
  ] = useState(0);

  const [
    progressAvailable,
    setProgressAvailable
  ] = useState(false);

  const [
    playableActivities,
    setPlayableActivities
  ] = useState<ResolvedPlayableActivity[]>([]);

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
          setProgressPercent(0);
          setProgressAvailable(false);
          setPlayableActivities([]);
          return;
        }

        const playable =
          getLearnerActivitiesForAgeBand(
            profile.ageBand
          );

        setPlayableActivities(
          playable
        );

        if (playable.length === 0) {
          setProgressPercent(0);
          setProgressAvailable(false);
          return;
        }

        setProgressAvailable(true);

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
        if (
          document.visibilityState ===
            "visible"
        ) {
          void refreshProgress();
        }
      };

      window.addEventListener(
        "focus",
        refreshOnFocus
      );

      document.addEventListener(
        "visibilitychange",
        refreshOnVisibility
      );

      return () => {
        window.removeEventListener(
          "focus",
          refreshOnFocus
        );

        document.removeEventListener(
          "visibilitychange",
          refreshOnVisibility
        );
      };
    },
    [
      refreshProgress
    ]
  );

  return {
    progressPercent,
    progressAvailable,
    playableActivities,
    refreshProgress
  };
}
