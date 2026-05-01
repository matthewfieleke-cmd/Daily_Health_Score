export type PrimaryFocus = "sleep" | "fiber" | "exercise" | "maintain";

export type SleepGoalHours = 7 | 7.5 | 8;
export type FiberGoalGrams = 30 | 40 | 50;

export type UserSettings = {
  sleepGoal: SleepGoalHours;
  fiberGoal: FiberGoalGrams;
};

export type DailyRecord = {
  date: string;
  sleepHours: number;
  fiberGrams: number;
  exerciseMinutes: number;
  sleepGoal: SleepGoalHours;
  fiberGoal: FiberGoalGrams;
  exerciseGoal: 30;
  sleepScore: number;
  fiberScore: number;
  exerciseScore: number;
  totalScore: number;
  sleepPercent: number;
  fiberPercent: number;
  exercisePercent: number;
  primaryFocus: PrimaryFocus;
  suggestion: string;
  createdAt: string;
  updatedAt: string;
};

export type ImportPayload = {
  date: string;
  sleep: number;
  fiber: number;
  exercise: number;
};

export type SuggestionCategory = "sleep" | "fiber" | "exercise" | "maintain";

export type UsedSuggestionsState = Record<SuggestionCategory, string[]>;
