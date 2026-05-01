import type { DailyRecord, PrimaryFocus, UserSettings } from "../types/health";
import { calculateScore, determinePrimaryFocus } from "./scoring";
import { getNextSuggestion } from "./suggestions";

export function buildDailyRecord(
  input: {
    date: string;
    sleepHours: number;
    fiberGrams: number;
    exerciseMinutes: number;
  },
  settings: UserSettings,
  now: Date = new Date(),
): DailyRecord {
  const goals = { sleepGoal: settings.sleepGoal, fiberGoal: settings.fiberGoal };
  const computed = calculateScore(
    {
      sleepHours: input.sleepHours,
      fiberGrams: input.fiberGrams,
      exerciseMinutes: input.exerciseMinutes,
    },
    goals,
  );
  const primaryFocus: PrimaryFocus = determinePrimaryFocus({
    sleepPercent: computed.sleepPercent,
    fiberPercent: computed.fiberPercent,
    exercisePercent: computed.exercisePercent,
  });
  const suggestion = getNextSuggestion(primaryFocus);
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
    createdAt: iso,
    updatedAt: iso,
  };
}
