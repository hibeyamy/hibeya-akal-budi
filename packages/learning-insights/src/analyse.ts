import {
  activityLearningMetadata
} from "./activityMetadata";

import type {
  LearningSessionInput,
  LearningSignal,
  LearningSummary,
  ObjectiveObservation
} from "./types";


const RECENT_WINDOW_DAYS =
  30;


function getSignal(
  exposureCount: number,
  attempts: number,
  successfulAttempts: number
): LearningSignal {

  if (
    exposureCount <= 1
  ) {
    return "exploring";
  }


  if (
    attempts === 0
  ) {
    return "exploring";
  }


  const successRatio =
    successfulAttempts /
    attempts;


  if (
    exposureCount >= 5 &&
    successRatio >= 0.8
  ) {
    return "showing-confidence";
  }


  if (
    exposureCount >= 3 &&
    successRatio >= 0.6
  ) {
    return "growing-familiarity";
  }


  return "developing";
}


export function analyseLearningSessions(
  sessions:
    readonly LearningSessionInput[],

  now =
    new Date()
): LearningSummary {

  const observations =
    new Map<
      string,
      ObjectiveObservation
    >();


  const recentBoundary =
    new Date(
      now.getTime() -
      RECENT_WINDOW_DAYS *
        24 *
        60 *
        60 *
        1000
    );


  let totalSeconds =
    0;


  for (
    const session of sessions
  ) {
    totalSeconds +=
      Math.max(
        0,
        session.durationSeconds
      );


    const metadata =
      activityLearningMetadata.find(
        (activity) =>
          activity.activityId ===
          session.activityId
      );


    if (!metadata) {
      continue;
    }


    const completedAt =
      new Date(
        session.completedAt
      );


    const isRecent =
      completedAt >=
      recentBoundary;


    for (
      const objectiveId
      of metadata.objectives
    ) {

      const existing =
        observations.get(
          objectiveId
        );


      if (!existing) {
        observations.set(
          objectiveId,
          {
            objectiveId,

            exposureCount:
              1,

            totalAttempts:
              session.attempts,

            successfulAttempts:
              session.correctCount,

            unsuccessfulAttempts:
              session.incorrectCount,

            recentExposureCount:
              isRecent
                ? 1
                : 0,

            signal:
              "exploring",

            lastObservedAt:
              session.completedAt
          }
        );

        continue;
      }


      existing.exposureCount +=
        1;

      existing.totalAttempts +=
        session.attempts;

      existing.successfulAttempts +=
        session.correctCount;

      existing.unsuccessfulAttempts +=
        session.incorrectCount;


      if (isRecent) {
        existing.recentExposureCount +=
          1;
      }


      if (
        completedAt >
        new Date(
          existing.lastObservedAt
        )
      ) {
        existing.lastObservedAt =
          session.completedAt;
      }
    }
  }


  const objectives =
    Array.from(
      observations.values()
    )
      .map(
        (
          observation
        ): ObjectiveObservation => ({
          ...observation,

          signal:
            getSignal(
              observation.exposureCount,
              observation.totalAttempts,
              observation.successfulAttempts
            )
        })
      )
      .sort(
        (a, b) =>
          b.lastObservedAt.localeCompare(
            a.lastObservedAt
          )
      );


  return {
    totalSessions:
      sessions.length,

    totalLearningMinutes:
      Math.round(
        totalSeconds /
        60
      ),

    objectives
  };
}
