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

  await database.put(
    "sessions",
    session
  );

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

  await database.put(
    "sessions",
    session
  );
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

  session.result = result;
  session.completedAt = result.completedAt;
  session.updatedAt = Date.now();
  session.syncStatus = "pending";

  await database.put(
    "sessions",
    session
  );
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

export async function getPendingSessions():
  Promise<StoredSession[]> {
  const database = await getDatabase();

  return database.getAllFromIndex(
    "sessions",
    "by-sync-status",
    "pending"
  );
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
export async function getLatestIncompleteSession():
  Promise<StoredSession | undefined> {
  const database = await getDatabase();

  const sessions = await database.getAllFromIndex(
    "sessions",
    "by-updated-at"
  );

  const incomplete = sessions
    .filter((session) => !session.completedAt)
    .sort(
      (a, b) =>
        b.updatedAt - a.updatedAt
    );

  return incomplete[0];
}
