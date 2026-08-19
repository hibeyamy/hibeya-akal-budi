export type LearningDomain =
  | "language"
  | "early-numeracy"
  | "thinking"
  | "visual-perception"
  | "fine-motor"
  | "world-around-us"
  | "social-emotional"
  | "values";


export type LearningSignal =
  | "exploring"
  | "developing"
  | "growing-familiarity"
  | "showing-confidence";


export interface LearningObjective {
  id: string;

  domain: LearningDomain;

  titleMs: string;

  titleEn: string;

  descriptionMs: string;

  descriptionEn: string;
}


export interface ActivityLearningMetadata {
  activityId: string;

  objectives: readonly string[];

  malaysiaElements?:
    readonly string[];
}


export interface LearningSessionInput {
  activityId: string;

  completedAt: string;

  correctCount: number;

  incorrectCount: number;

  attempts: number;

  durationSeconds: number;
}


export interface ObjectiveObservation {
  objectiveId: string;

  exposureCount: number;

  totalAttempts: number;

  successfulAttempts: number;

  unsuccessfulAttempts: number;

  recentExposureCount: number;

  signal: LearningSignal;

  lastObservedAt: string;
}


export interface LearningSummary {
  totalSessions: number;

  totalLearningMinutes: number;

  objectives:
    ObjectiveObservation[];
}
