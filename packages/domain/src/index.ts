export type AgeBand =
  | "2-3"
  | "3-4"
  | "4-5"
  | "5-6";

export type LearningDomain =
  | "numeracy"
  | "language"
  | "memory"
  | "logic"
  | "social"
  | "life-skill";

export interface Skill {
  id: string;
  domain: LearningDomain;
  name: string;
}

export interface Activity {
  id: string;
  mechanic: string;
  ageBand: AgeBand;
  skills: string[];
  difficulty: number;
}

export interface ActivityResult {
  activityId: string;
  correct: number;
  incorrect: number;
  attempts: number;
  durationSeconds: number;
}
