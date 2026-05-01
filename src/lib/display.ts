import type { PrimaryFocus } from "../types/health";

const LABELS: Record<PrimaryFocus, string> = {
  sleep: "Sleep",
  fiber: "Fiber",
  exercise: "Exercise",
  maintain: "Maintain balance",
};

export function primaryFocusLabel(focus: PrimaryFocus): string {
  return LABELS[focus];
}
