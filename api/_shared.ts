import type {
  DailyRecord,
  UsedSuggestionsState,
  UserSettings,
} from "../src/types/health";

export const EMPTY_USED: UsedSuggestionsState = {
  sleep: [],
  fiber: [],
  exercise: [],
  maintain: [],
};

export const DEFAULT_SETTINGS: UserSettings = {
  sleepGoal: 7.5,
  fiberGoal: 40,
};

export function sortRecordsDesc(records: DailyRecord[]): DailyRecord[] {
  return [...records].sort((a, b) => b.date.localeCompare(a.date));
}

export function trimRecords(records: DailyRecord[], max = 30): DailyRecord[] {
  return sortRecordsDesc(records).slice(0, max);
}

export function safePrefix(token: string): string {
  const t = token.trim().replace(/[^a-zA-Z0-9_-]/g, "");
  if (t.length < 24) throw new Error("invalid_token");
  return `dhs:${t}`;
}

export function parseBearer(auth: string | undefined): string | null {
  if (!auth?.startsWith("Bearer ")) return null;
  const raw = auth.slice(7).trim();
  return raw.length >= 24 ? raw : null;
}
