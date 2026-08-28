import {
  useCallback,
  useReducer
} from "react";

import {
  initialLearnerJourneyState,
  learnerJourneyReducer
} from "./learnerJourney";

export function useLearnerJourney() {
  const [
    state,
    dispatch
  ] =
    useReducer(
      learnerJourneyReducer,
      initialLearnerJourneyState
    );

  const goHome =
    useCallback(
      () => {
        dispatch({
          type:
            "GO_HOME"
        });
      },
      []
    );

  const goExplore =
    useCallback(
      () => {
        dispatch({
          type:
            "GO_EXPLORE"
        });
      },
      []
    );

  const openActivity =
    useCallback(
      (
        activityId:
          string,

        from:
          "home" |
          "explore"
      ) => {
        dispatch({
          type:
            "OPEN_ACTIVITY",

          activityId,

          from
        });
      },
      []
    );

  const closeActivity =
    useCallback(
      () => {
        dispatch({
          type:
            "CLOSE_ACTIVITY"
        });
      },
      []
    );

  return {
    state,
    goHome,
    goExplore,
    openActivity,
    closeActivity
  };
}
