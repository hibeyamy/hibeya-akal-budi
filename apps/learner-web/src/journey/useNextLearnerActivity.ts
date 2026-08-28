import {
  useCallback
} from "react";

import {
  getCachedLearnerRuntimeProfile,
  getLearnerJourneyState
} from "@akal-budi/offline";

import {
  selectLearnerActivity
} from "../features/play/selectLearnerActivity";

import {
  getLearnerSkillProgress
} from "../services/skillMasteryService";

export interface UseNextLearnerActivityInput {
  openActivity:
    (
      activityId: string,
      from:
        "home" |
        "explore"
    ) => void;
}

export function useNextLearnerActivity({
  openActivity
}: UseNextLearnerActivityInput) {
  const openNextActivity =
    useCallback(
      async () => {
        const [
          journey,
          profile,
          skillProgress
        ] =
          await Promise.all([
            getLearnerJourneyState(),
            getCachedLearnerRuntimeProfile(),
            getLearnerSkillProgress()
          ]);

        if (!profile) {
          return;
        }

        const activity =
          selectLearnerActivity({
            childId:
              profile.childId,

            ageBand:
              profile.ageBand,

            lastCompletedActivityId:
              journey.lastCompletedActivityId,

            completedActivityIds:
              journey.completedActivityIds,

            masteredSkillIds:
              skillProgress
                .filter(
                  skill =>
                    skill.level ===
                      "mastered"
                )
                .map(
                  skill =>
                    skill.skillId
                ),

            skillProgress
          });

        if (!activity) {
          return;
        }

        openActivity(
          activity.id,
          "home"
        );
      },
      [
        openActivity
      ]
    );

  return {
    openNextActivity
  };
}
