import {
  getDatabase,
  type AdaptiveObservationAuthority,
  type AdaptiveObservationFallbackReason,
  type StoredAdaptiveObservation
} from "./database";


export interface QueueAdaptiveObservationInput {
  eventId?: string;

  occurredAt:
    number;

  authority:
    AdaptiveObservationAuthority;

  fallbackReason:
    AdaptiveObservationFallbackReason;

  rolloutBucket:
    number;

  rolloutPercent:
    number;

  legacyActivityId:
    string;

  adaptiveActivityId:
    string | null;

  selectedActivityId:
    string;
}


function createEventId():
  string {
  if (
    typeof crypto !==
      "undefined" &&
    typeof crypto.randomUUID ===
      "function"
  ) {
    return crypto.randomUUID();
  }

  return [
    Date.now().toString(
      36
    ),
    Math.random()
      .toString(
        36
      )
      .slice(
        2
      )
  ].join(
    "-"
  );
}


function validateInput(
  input:
    QueueAdaptiveObservationInput
): void {
  if (
    !Number.isFinite(
      input.occurredAt
    ) ||
    input.occurredAt <=
      0
  ) {
    throw new Error(
      "Invalid adaptive observation occurredAt."
    );
  }

  if (
    !Number.isInteger(
      input.rolloutBucket
    ) ||
    input.rolloutBucket <
      0 ||
    input.rolloutBucket >
      99
  ) {
    throw new Error(
      "Invalid adaptive observation rolloutBucket."
    );
  }

  if (
    !Number.isFinite(
      input.rolloutPercent
    ) ||
    input.rolloutPercent <
      0 ||
    input.rolloutPercent >
      100
  ) {
    throw new Error(
      "Invalid adaptive observation rolloutPercent."
    );
  }

  for (
    const value
    of [
      input.legacyActivityId,
      input.selectedActivityId
    ]
  ) {
    if (
      typeof value !==
        "string" ||
      value.length ===
        0 ||
      value.length >
        200
    ) {
      throw new Error(
        "Invalid adaptive observation activity id."
      );
    }
  }

  if (
    input.adaptiveActivityId !==
      null &&
    (
      input.adaptiveActivityId.length ===
        0 ||
      input.adaptiveActivityId.length >
        200
    )
  ) {
    throw new Error(
      "Invalid adaptive observation adaptive activity id."
    );
  }
}


export async function queueAdaptiveObservation(
  input:
    QueueAdaptiveObservationInput
):
  Promise<
    StoredAdaptiveObservation
  > {
  validateInput(
    input
  );

  const database =
    await getDatabase();

  const now =
    Date.now();

  const observation:
    StoredAdaptiveObservation = {
      eventId:
        input.eventId ??
        createEventId(),

      occurredAt:
        input.occurredAt,

      authority:
        input.authority,

      fallbackReason:
        input.fallbackReason,

      rolloutBucket:
        input.rolloutBucket,

      rolloutPercent:
        input.rolloutPercent,

      legacyActivityId:
        input.legacyActivityId,

      adaptiveActivityId:
        input.adaptiveActivityId,

      selectedActivityId:
        input.selectedActivityId,

      syncStatus:
        "pending",

      createdAt:
        now,

      updatedAt:
        now
    };

  /*
   * put() makes local replay idempotent by eventId.
   */
  await database.put(
    "adaptiveObservations",
    observation
  );

  return observation;
}


export async function getPendingAdaptiveObservations():
  Promise<
    StoredAdaptiveObservation[]
  > {
  const database =
    await getDatabase();

  const observations =
    await database.getAllFromIndex(
      "adaptiveObservations",
      "by-sync-status",
      "pending"
    );

  return observations
    .filter(
      isStoredAdaptiveObservation
    )
    .sort(
      (
        left,
        right
      ) =>
        left.occurredAt -
        right.occurredAt
    );
}


export async function markAdaptiveObservationSynced(
  eventId:
    string
): Promise<void> {
  const database =
    await getDatabase();

  const observation =
    await database.get(
      "adaptiveObservations",
      eventId
    );

  if (!observation) {
    return;
  }

  observation.syncStatus =
    "synced";

  observation.updatedAt =
    Date.now();

  await database.put(
    "adaptiveObservations",
    observation
  );
}


export async function getAdaptiveObservation(
  eventId:
    string
):
  Promise<
    StoredAdaptiveObservation |
    undefined
  > {
  const database =
    await getDatabase();

  return database.get(
    "adaptiveObservations",
    eventId
  );
}


export function isStoredAdaptiveObservation(
  value:
    unknown
):
  value is
    StoredAdaptiveObservation {
  if (
    typeof value !==
      "object" ||
    value ===
      null
  ) {
    return false;
  }

  const candidate =
    value as
      Partial<
        StoredAdaptiveObservation
      >;

  return (
    typeof candidate.eventId ===
      "string" &&
    candidate.eventId.length >
      0 &&
    typeof candidate.occurredAt ===
      "number" &&
    Number.isFinite(
      candidate.occurredAt
    ) &&
    (
      candidate.authority ===
        "legacy" ||
      candidate.authority ===
        "adaptive"
    ) &&
    typeof candidate.fallbackReason ===
      "string" &&
    Number.isInteger(
      candidate.rolloutBucket
    ) &&
    candidate.rolloutBucket! >=
      0 &&
    candidate.rolloutBucket! <=
      99 &&
    typeof candidate.rolloutPercent ===
      "number" &&
    Number.isFinite(
      candidate.rolloutPercent
    ) &&
    typeof candidate.legacyActivityId ===
      "string" &&
    (
      candidate.adaptiveActivityId ===
        null ||
      typeof candidate.adaptiveActivityId ===
        "string"
    ) &&
    typeof candidate.selectedActivityId ===
      "string" &&
    (
      candidate.syncStatus ===
        "pending" ||
      candidate.syncStatus ===
        "synced" ||
      candidate.syncStatus ===
        "failed"
    ) &&
    typeof candidate.createdAt ===
      "number" &&
    typeof candidate.updatedAt ===
      "number"
  );
}
