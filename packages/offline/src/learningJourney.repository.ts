import {
  getDatabase
} from "./database";


const JOURNEY_KEY =
  "learner-journey-state";


export interface LearnerJourneyState {
  lastCompletedActivityId:
    string | null;

  completedSessionCount:
    number;

  updatedAt:
    number;
}


const emptyJourney:
  LearnerJourneyState = {
    lastCompletedActivityId:
      null,

    completedSessionCount:
      0,

    updatedAt:
      0
  };


export async function getLearnerJourneyState():
  Promise<LearnerJourneyState> {
  const db =
    await getDatabase();

  const stored =
    await db.get(
      "settings",
      JOURNEY_KEY
    );

  if (
    !stored ||
    !isJourneyState(
      stored.value
    )
  ) {
    return {
      ...emptyJourney
    };
  }

  return stored.value;
}


export async function recordCompletedJourneyActivity(
  activityId: string
): Promise<LearnerJourneyState> {
  const current =
    await getLearnerJourneyState();

  const next:
    LearnerJourneyState = {
      lastCompletedActivityId:
        activityId,

      completedSessionCount:
        current.completedSessionCount +
        1,

      updatedAt:
        Date.now()
    };

  const db =
    await getDatabase();

  await db.put(
    "settings",
    {
      key:
        JOURNEY_KEY,

      value:
        next
    }
  );

  return next;
}


export async function clearLearnerJourneyState():
  Promise<void> {
  const db =
    await getDatabase();

  await db.delete(
    "settings",
    JOURNEY_KEY
  );
}


function isJourneyState(
  value: unknown
): value is LearnerJourneyState {
  if (
    typeof value !==
      "object" ||
    value ===
      null
  ) {
    return false;
  }

  const candidate =
    value as Record<
      string,
      unknown
    >;

  return (
    (
      candidate
        .lastCompletedActivityId ===
        null ||
      typeof candidate
        .lastCompletedActivityId ===
        "string"
    ) &&
    typeof candidate
      .completedSessionCount ===
      "number" &&
    Number.isInteger(
      candidate
        .completedSessionCount
    ) &&
    candidate
      .completedSessionCount >=
      0 &&
    typeof candidate.updatedAt ===
      "number"
  );
}