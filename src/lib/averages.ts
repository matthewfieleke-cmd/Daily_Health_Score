import type { DailyRecord } from "../types/health";
import { calculateScore } from "./scoring";

export type RollingStats = {
  daysInWindow: number;
  daysWithData: number;
  avgTotalScore: number;
  avgSleepHours: number;
  avgFiberGrams: number;
  avgExerciseMinutes: number;
  avgSleepScore: number;
  avgFiberScore: number;
  avgExerciseScore: number;
  recordsInWindow: DailyRecord[];
};

function mean(values: number[]): number {
  if (values.length === 0) return 0;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

/** Averages recalculated from raw metrics and goals stored on each record. */
export function getRollingAverages(
  allRecords: DailyRecord[],
  windowDateKeys: string[],
): RollingStats | null {
  const keySet = new Set(windowDateKeys);
  const recordsInWindow = allRecords
    .filter((r) => keySet.has(r.date))
    .sort((a, b) => b.date.localeCompare(a.date));

  const daysInWindow = windowDateKeys.length;
  const daysWithData = recordsInWindow.length;
  if (daysWithData === 0) return null;

  const recalculated = recordsInWindow.map((r) =>
    calculateScore(
      {
        sleepHours: r.sleepHours,
        fiberGrams: r.fiberGrams,
        exerciseMinutes: r.exerciseMinutes,
      },
      { sleepGoal: r.sleepGoal, fiberGoal: r.fiberGoal },
    ),
  );

  return {
    daysInWindow,
    daysWithData,
    avgTotalScore: mean(recalculated.map((x) => x.totalScore)),
    avgSleepHours: mean(recordsInWindow.map((r) => r.sleepHours)),
    avgFiberGrams: mean(recordsInWindow.map((r) => r.fiberGrams)),
    avgExerciseMinutes: mean(recordsInWindow.map((r) => r.exerciseMinutes)),
    avgSleepScore: mean(recalculated.map((x) => x.sleepScore)),
    avgFiberScore: mean(recalculated.map((x) => x.fiberScore)),
    avgExerciseScore: mean(recalculated.map((x) => x.exerciseScore)),
    recordsInWindow,
  };
}
