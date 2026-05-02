import type { PrimaryFocus } from "../types/health.js";
import type { SleepGoalHours, FiberGoalGrams } from "../types/health.js";

const EXERCISE_GOAL_MINUTES = 30;

export type MetricInput = {
  sleepHours: number;
  fiberGrams: number;
  exerciseMinutes: number;
};

export type GoalInput = {
  sleepGoal: SleepGoalHours;
  fiberGoal: FiberGoalGrams;
};

export type ScoreComputation = {
  sleepScore: number;
  fiberScore: number;
  exerciseScore: number;
  totalScore: number;
  sleepPercent: number;
  fiberPercent: number;
  exercisePercent: number;
};

export function calculateScore(metrics: MetricInput, goals: GoalInput): ScoreComputation {
  const sleepScore = Math.min(metrics.sleepHours / goals.sleepGoal, 1) * 4;
  const fiberScore = Math.min(metrics.fiberGrams / goals.fiberGoal, 1) * 4;
  const exerciseScore =
    Math.min(metrics.exerciseMinutes / EXERCISE_GOAL_MINUTES, 1) * 2;
  const totalScore = sleepScore + fiberScore + exerciseScore;
  const sleepPercent = metrics.sleepHours / goals.sleepGoal;
  const fiberPercent = metrics.fiberGrams / goals.fiberGoal;
  const exercisePercent = metrics.exerciseMinutes / EXERCISE_GOAL_MINUTES;

  return {
    sleepScore,
    fiberScore,
    exerciseScore,
    totalScore,
    sleepPercent,
    fiberPercent,
    exercisePercent,
  };
}

const TIE_PRIORITY: PrimaryFocus[] = ["sleep", "fiber", "exercise"];

export function determinePrimaryFocus(
  p: Pick<ScoreComputation, "sleepPercent" | "fiberPercent" | "exercisePercent">,
): PrimaryFocus {
  if (p.sleepPercent >= 1 && p.fiberPercent >= 1 && p.exercisePercent >= 1) {
    return "maintain";
  }
  const min = Math.min(p.sleepPercent, p.fiberPercent, p.exercisePercent);
  const eps = 1e-9;
  const tied = TIE_PRIORITY.filter((key) => {
    const val =
      key === "sleep"
        ? p.sleepPercent
        : key === "fiber"
          ? p.fiberPercent
          : p.exercisePercent;
    return Math.abs(val - min) < eps;
  });
  return tied[0] ?? "sleep";
}

/** Format numeric score for UI (one decimal). */
export function formatDisplayScore(value: number): string {
  const rounded = Math.round(value * 10) / 10;
  return rounded.toFixed(1);
}
