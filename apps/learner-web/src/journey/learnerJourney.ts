export type LearnerJourneyView =
  | "home"
  | "explore"
  | "activity";

export interface LearnerJourneyState {
  view:
    LearnerJourneyView;

  activeActivityId:
    string | null;

  previousView:
    Exclude<
      LearnerJourneyView,
      "activity"
    > | null;
}

export type LearnerJourneyAction =
  | {
      type:
        "GO_HOME";
    }
  | {
      type:
        "GO_EXPLORE";
    }
  | {
      type:
        "OPEN_ACTIVITY";

      activityId:
        string;

      from:
        "home" |
        "explore";
    }
  | {
      type:
        "CLOSE_ACTIVITY";
    };

export const initialLearnerJourneyState:
  LearnerJourneyState = {
    view:
      "home",

    activeActivityId:
      null,

    previousView:
      null
  };

export function learnerJourneyReducer(
  state:
    LearnerJourneyState,

  action:
    LearnerJourneyAction
):
  LearnerJourneyState {
  switch (
    action.type
  ) {
    case "GO_HOME":
      return {
        view:
          "home",

        activeActivityId:
          null,

        previousView:
          null
      };

    case "GO_EXPLORE":
      return {
        view:
          "explore",

        activeActivityId:
          null,

        previousView:
          null
      };

    case "OPEN_ACTIVITY":
      return {
        view:
          "activity",

        activeActivityId:
          action.activityId,

        previousView:
          action.from
      };

    case "CLOSE_ACTIVITY":
      return {
        view:
          state.previousView ??
          "home",

        activeActivityId:
          null,

        previousView:
          null
      };

    default:
      return state;
  }
}
