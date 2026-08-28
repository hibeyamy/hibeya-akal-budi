import type {
  GameAnswer,
  GameSessionResult
} from "@akal-budi/game-runtime";

import {
  getDatabase,
  type StoredSession
} from "./database";

export interface CreateLocalSessionInput {
  id: string;
  activityId: string;
  activityVersion: number;
  startedAt: number;
}

export async function createLocalSession(
  input: CreateLocalSessionInput
): Promise<StoredSession> {
  const database = await getDatabase();

  const now = Date.now();

  const session: StoredSession = {
    id: input.id,
    activityId: input.activityId,
    activityVersion: input.activityVersion,
    startedAt: input.startedAt,
    answers: [],
    syncStatus: "pending",
    createdAt: now,
    updatedAt: now
  };

  await database.put("sessions", session);

  return session;
}

export async function addLocalAnswer(
  sessionId: string,
  answer: GameAnswer
): Promise<void> {
  const database = await getDatabase();

  const session = await database.get(
    "sessions",
    sessionId
  );

  if (!session) {
    throw new Error(
      `Local session not found: ${sessionId}`
    );
  }

  session.answers.push(answer);
  session.updatedAt = Date.now();
  session.syncStatus = "pending";

  await database.put("sessions", session);
}

export async function completeLocalSession(
  sessionId: string,
  result: GameSessionResult
): Promise<void> {
  const database = await getDatabase();

  const session = await database.get(
    "sessions",
    sessionId
  );

  if (!session) {
    throw new Error(
      `Local session not found: ${sessionId}`
    );
  }

  if (
    session.activityId !== result.activityId ||
    session.activityVersion !== result.activityVersion
  ) {
    throw new Error(
      `Session result does not match local session: ${sessionId}`
    );
  }

  // Completion is immutable once committed. A replay after reload or
  // retry must not replace the original result/completion timestamp.
  if (session.completedAt || session.result) {
    return;
  }

  session.result = result;
  session.completedAt = result.completedAt;
  session.updatedAt = Date.now();
  session.syncStatus = "pending";

  await database.put("sessions", session);
}

export async function getLocalSession(
  sessionId: string
): Promise<StoredSession | undefined> {
  const database = await getDatabase();

  return database.get(
    "sessions",
    sessionId
  );
}


export async function deleteLocalSession(
  sessionId: string
): Promise<void> {
  const database = await getDatabase();

  await database.delete(
    "sessions",
    sessionId
  );
}

export async function getPendingSessions():
  Promise<StoredSession[]> {
  const database = await getDatabase();

  const sessions = await database.getAllFromIndex(
    "sessions",
    "by-sync-status",
    "pending"
  );

  return sessions
    .filter(isStoredSession)
    .filter(isSyncableCompletedSession);
}

export async function getLatestIncompleteSession():
  Promise<StoredSession | undefined> {
  const database = await getDatabase();

  const sessions = await database.getAllFromIndex(
    "sessions",
    "by-updated-at"
  );

  return sessions
    .filter(isStoredSession)
    .filter((session) => !session.completedAt)
    .sort(
      (a, b) =>
        b.updatedAt - a.updatedAt
    )[0];
}

export async function getLatestIncompleteSessionForActivity(
  activityId: string,
  activityVersion: number
): Promise<StoredSession | undefined> {
  const database = await getDatabase();

  const sessions = await database.getAllFromIndex(
    "sessions",
    "by-activity-id",
    activityId
  );

  return sessions
    .filter(isStoredSession)
    .filter(
      (session) =>
        !session.completedAt &&
        session.activityVersion === activityVersion
    )
    .sort(
      (a, b) =>
        b.updatedAt - a.updatedAt
    )[0];
}

export async function markSessionSynced(
  sessionId: string
): Promise<void> {
  const database = await getDatabase();

  const session = await database.get(
    "sessions",
    sessionId
  );

  if (!session) {
    return;
  }

  session.syncStatus = "synced";
  session.updatedAt = Date.now();

  await database.put(
    "sessions",
    session
  );
}

export async function markSessionFailed(
  sessionId: string
): Promise<void> {
  const database = await getDatabase();

  const session = await database.get(
    "sessions",
    sessionId
  );

  if (!session) {
    return;
  }

  session.syncStatus = "failed";
  session.updatedAt = Date.now();

  await database.put(
    "sessions",
    session
  );
}


function isStoredSession(
  value: unknown
): value is StoredSession {
  if (
    typeof value !== "object" ||
    value === null
  ) {
    return false;
  }

  const candidate = value as Record<string, unknown>;

  return (
    typeof candidate.id === "string" &&
    candidate.id.length > 0 &&
    typeof candidate.activityId === "string" &&
    candidate.activityId.length > 0 &&
    typeof candidate.activityVersion === "number" &&
    Number.isInteger(candidate.activityVersion) &&
    candidate.activityVersion > 0 &&
    typeof candidate.startedAt === "number" &&
    Number.isFinite(candidate.startedAt) &&
    Array.isArray(candidate.answers) &&
    candidate.answers.every(isGameAnswer) &&
    (
      candidate.result === undefined ||
      isGameSessionResult(candidate.result)
    ) &&
    (
      candidate.completedAt === undefined ||
      (
        typeof candidate.completedAt === "number" &&
        Number.isFinite(candidate.completedAt)
      )
    ) &&
    (
      candidate.syncStatus === "pending" ||
      candidate.syncStatus === "synced" ||
      candidate.syncStatus === "failed"
    ) &&
    typeof candidate.createdAt === "number" &&
    Number.isFinite(candidate.createdAt) &&
    typeof candidate.updatedAt === "number" &&
    Number.isFinite(candidate.updatedAt)
  );
}

function isSyncableCompletedSession(
  session: StoredSession
): boolean {
  return (
    session.completedAt !== undefined &&
    session.result !== undefined &&
    session.result.activityId === session.activityId &&
    session.result.activityVersion === session.activityVersion
  );
}

function isGameAnswer(
  value: unknown
): value is GameAnswer {
  if (
    typeof value !== "object" ||
    value === null
  ) {
    return false;
  }

  const candidate = value as Record<string, unknown>;

  return (
    typeof candidate.optionId === "string" &&
    candidate.optionId.length > 0 &&
    typeof candidate.correct === "boolean" &&
    typeof candidate.answeredAt === "number" &&
    Number.isFinite(candidate.answeredAt)
  );
}

function isGameSessionResult(
  value: unknown
): value is GameSessionResult {
  if (
    typeof value !== "object" ||
    value === null
  ) {
    return false;
  }

  const candidate = value as Record<string, unknown>;

  return (
    typeof candidate.activityId === "string" &&
    candidate.activityId.length > 0 &&
    typeof candidate.activityVersion === "number" &&
    Number.isInteger(candidate.activityVersion) &&
    candidate.activityVersion > 0 &&
    isNonNegativeInteger(candidate.correct) &&
    isNonNegativeInteger(candidate.incorrect) &&
    isNonNegativeInteger(candidate.attempts) &&
    typeof candidate.durationSeconds === "number" &&
    Number.isFinite(candidate.durationSeconds) &&
    candidate.durationSeconds >= 0 &&
    typeof candidate.completedAt === "number" &&
    Number.isFinite(candidate.completedAt)
  );
}

function isNonNegativeInteger(
  value: unknown
): value is number {
  return (
    typeof value === "number" &&
    Number.isInteger(value) &&
    value >= 0
  );
}
