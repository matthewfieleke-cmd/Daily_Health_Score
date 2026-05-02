import type { DailyRecord, UserSettings } from "../types/health";
import { composeDailyRecord } from "./record-compose";
import { calculateScore, determinePrimaryFocus } from "./scoring";
import { getNextSuggestion } from "./suggestions";
import { localDateKey } from "./dates";

export { composeDailyRecord } from "./record-compose";

export function buildDailyRecord(
  input: {
    date: string;
    sleepHours: number;
    fiberGrams: number;
    exerciseMinutes: number;
    completionStatus?: DailyRecord["completionStatus"];
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
  const primaryFocus = determinePrimaryFocus({
    sleepPercent: computed.sleepPercent,
    fiberPercent: computed.fiberPercent,
    exercisePercent: computed.exercisePercent,
  });
  const suggestion = getNextSuggestion(primaryFocus);
  return composeDailyRecord(
    {
      ...input,
      completionStatus:
        input.completionStatus ??
        (input.date === localDateKey(now) ? "partial" : "complete"),
    },
    settings,
    computed,
    primaryFocus,
    suggestion,
    now,
  );
}
