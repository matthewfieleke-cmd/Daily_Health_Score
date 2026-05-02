import type { DailyRecord, PrimaryFocus, UserSettings } from "../types/health.js";
import type { ScoreComputation } from "./scoring.js";

/** Pure assembly of a daily record — safe for serverless (no storage side effects). */
export function composeDailyRecord(
  input: {
    date: string;
    sleepHours: number;
    fiberGrams: number;
    exerciseMinutes: number;
    completionStatus?: DailyRecord["completionStatus"];
  },
  settings: UserSettings,
  computed: ScoreComputation,
  primaryFocus: PrimaryFocus,
  suggestion: string,
  now: Date,
): DailyRecord {
  const iso = now.toISOString();
  return {
    date: input.date,
    sleepHours: input.sleepHours,
    fiberGrams: input.fiberGrams,
    exerciseMinutes: input.exerciseMinutes,
    sleepGoal: settings.sleepGoal,
    fiberGoal: settings.fiberGoal,
    exerciseGoal: 30,
    sleepScore: computed.sleepScore,
    fiberScore: computed.fiberScore,
    exerciseScore: computed.exerciseScore,
    totalScore: computed.totalScore,
    sleepPercent: computed.sleepPercent,
    fiberPercent: computed.fiberPercent,
    exercisePercent: computed.exercisePercent,
    primaryFocus,
    suggestion,
    completionStatus: input.completionStatus,
    createdAt: iso,
    updatedAt: iso,
  };
}
