export interface LearnerProgressInput {
  completedActivityIds:
    readonly string[];

  playableActivityIds:
    readonly string[];
}

export function calculateLearnerProgressPercent({
  completedActivityIds,
  playableActivityIds
}: LearnerProgressInput):
  number {
  const playable =
    new Set(
      playableActivityIds.filter(
        id =>
          typeof id ===
            "string" &&
          id.length >
            0
      )
    );

  if (
    playable.size ===
      0
  ) {
    return 0;
  }

  const completed =
    new Set(
      completedActivityIds.filter(
        id =>
          playable.has(
            id
          )
      )
    );

  return Math.min(
    100,
    Math.round(
      (
        completed.size /
        playable.size
      ) *
      100
    )
  );
}
