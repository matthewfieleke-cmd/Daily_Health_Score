import type { PrimaryFocus } from "../types/health";
import { advanceSuggestion } from "./suggestion-engine";
import { loadUsedSuggestions, persistUsedSuggestions } from "./storage";

export function getNextSuggestion(primaryFocus: PrimaryFocus): string {
  const state = loadUsedSuggestions();
  const { text, nextState } = advanceSuggestion(primaryFocus, state);
  persistUsedSuggestions(nextState);
  return text;
}
