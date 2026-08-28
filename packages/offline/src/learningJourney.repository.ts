import {
  getDatabase
} from "./database";


const JOURNEY_KEY =
  "learner-journey-state";

const JOURNEY_PROCESSED_SESSIONS_KEY =
  "learner-journey-processed-sessions-v1";


export interface LearnerJourneyState {
  lastCompletedActivityId:
    string | null;

  completedSessionCount:
    number;

  completedActivityIds:
    string[];

  updatedAt:
    number;
}


const emptyJourney:
  LearnerJourneyState = {
    lastCompletedActivityId:
      null,

    completedSessionCount:
      0,

    completedActivityIds:
      [],

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

  return normalizeJourneyState(
    stored.value
  );
}


export async function recordCompletedJourneyActivity(
  activityId: string,
  sessionId?: string
): Promise<LearnerJourneyState> {
  const db =
    await getDatabase();

  const transaction =
    db.transaction(
      "settings",
      "readwrite"
    );

  const [
    journeyStored,
    processedStored
  ] = await Promise.all([
    transaction.store.get(
      JOURNEY_KEY
    ),
    transaction.store.get(
      JOURNEY_PROCESSED_SESSIONS_KEY
    )
  ]);

  const current =
    journeyStored &&
    isJourneyState(
      journeyStored.value
    )
      ? normalizeJourneyState(
          journeyStored.value
        )
      : {
          ...emptyJourney
        };

  const processedSessionIds =
    normalizeProcessedSessionIds(
      processedStored?.value
    );

  if (
    sessionId &&
    processedSessionIds.includes(
      sessionId
    )
  ) {
    await transaction.done;
    return current;
  }

  const completedActivityIds =
    current.completedActivityIds.includes(
      activityId
    )
      ? current.completedActivityIds
      : [
          ...current.completedActivityIds,
          activityId
        ];

  const next:
    LearnerJourneyState = {
      lastCompletedActivityId:
        activityId,

      completedSessionCount:
        current.completedSessionCount +
        1,

      completedActivityIds,

      updatedAt:
        Date.now()
    };

  await transaction.store.put({
    key:
      JOURNEY_KEY,
    value:
      next
  });

  if (sessionId) {
    await transaction.store.put({
      key:
        JOURNEY_PROCESSED_SESSIONS_KEY,
      value:
        [
          ...processedSessionIds,
          sessionId
        ]
    });
  }

  await transaction.done;

  return next;
}


export async function clearLearnerJourneyState():
  Promise<void> {
  const db =
    await getDatabase();

  const transaction =
    db.transaction(
      "settings",
      "readwrite"
    );

  await Promise.all([
    transaction.store.delete(
      JOURNEY_KEY
    ),
    transaction.store.delete(
      JOURNEY_PROCESSED_SESSIONS_KEY
    )
  ]);

  await transaction.done;
}


interface LegacyLearnerJourneyState {
  lastCompletedActivityId:
    string | null;

  completedSessionCount:
    number;

  completedActivityIds?:
    unknown;

  updatedAt:
    number;
}


function normalizeJourneyState(
  value:
    LegacyLearnerJourneyState
):
  LearnerJourneyState {
  const storedIds =
    Array.isArray(
      value.completedActivityIds
    )
      ? value.completedActivityIds.filter(
          (
            candidate
          ): candidate is string =>
            typeof candidate ===
              "string" &&
            candidate.length >
              0
        )
      : [];

  const completedActivityIds =
    storedIds.length >
      0
      ? Array.from(
          new Set(
            storedIds
          )
        )
      : value.lastCompletedActivityId
        ? [
            value.lastCompletedActivityId
          ]
        : [];

  return {
    lastCompletedActivityId:
      value.lastCompletedActivityId,

    completedSessionCount:
      value.completedSessionCount,

    completedActivityIds,

    updatedAt:
      value.updatedAt
  };
}


function isJourneyState(
  value: unknown
): value is LegacyLearnerJourneyState {
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


function normalizeProcessedSessionIds(
  value: unknown
): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return Array.from(
    new Set(
      value.filter(
        (candidate): candidate is string =>
          typeof candidate === "string" &&
          candidate.length > 0
      )
    )
  );
}
