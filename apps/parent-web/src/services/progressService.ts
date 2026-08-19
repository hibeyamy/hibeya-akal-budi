import type {
  LearningSessionInput
} from "@akal-budi/learning-insights";

import {
  supabase
} from "../lib/supabase";


export interface ParentLearningSession {
  id: string;

  childId: string;

  activityId: string;

  activityVersion: number;

  startedAt: string;

  completedAt: string;

  correctCount: number;

  incorrectCount: number;

  attempts: number;

  durationSeconds: number;
}


export async function getChildLearningSessions(
  childId: string
): Promise<ParentLearningSession[]> {
  const {
    data,
    error
  } =
    await supabase
      .from(
        "learning_sessions"
      )
      .select(
        `
          id,
          child_id,
          activity_id,
          activity_version,
          started_at,
          completed_at,
          correct_count,
          incorrect_count,
          attempts,
          duration_seconds
        `
      )
      .eq(
        "child_id",
        childId
      )
      .order(
        "completed_at",
        {
          ascending: false
        }
      )
      .limit(500);


  if (error) {
    throw error;
  }


  return (
    data ?? []
  ).map(
    (row) => ({
      id:
        row.id,

      childId:
        row.child_id,

      activityId:
        row.activity_id,

      activityVersion:
        row.activity_version,

      startedAt:
        row.started_at,

      completedAt:
        row.completed_at,

      correctCount:
        row.correct_count,

      incorrectCount:
        row.incorrect_count,

      attempts:
        row.attempts,

      durationSeconds:
        row.duration_seconds
    })
  );
}


export function toLearningSessionInput(
  session: ParentLearningSession
): LearningSessionInput {
  return {
    activityId:
      session.activityId,

    completedAt:
      session.completedAt,

    correctCount:
      session.correctCount,

    incorrectCount:
      session.incorrectCount,

    attempts:
      session.attempts,

    durationSeconds:
      session.durationSeconds
  };
}
