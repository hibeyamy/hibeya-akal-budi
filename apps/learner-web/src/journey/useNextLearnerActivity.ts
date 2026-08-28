import {
  useCallback,
  useState
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
  const [
    selectionError,
    setSelectionError
  ] = useState<string | null>(null);

  const openNextActivity =
    useCallback(
      async () => {
        setSelectionError(null);

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
          setSelectionError(
            "Profil pembelajaran belum tersedia. Muat semula halaman dan cuba lagi."
          );
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
          setSelectionError(
            "Tiada aktiviti seterusnya dapat dipilih. Gunakan Teroka sementara perjalanan pembelajaran disemak."
          );
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
    openNextActivity,
    selectionError
  };
}
