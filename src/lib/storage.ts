import type {
  DailyRecord,
  UsedSuggestionsState,
  UserSettings,
} from "../types/health";

import { notifyRecordsUpdated } from "./storage-events";

export const SYNC_TOKEN_KEY = "dailyHealthScore.syncToken";

export const STORAGE_KEYS = {
  records: "dailyHealthScore.records",
  settings: "dailyHealthScore.settings",
  usedSuggestions: "dailyHealthScore.usedSuggestions",
  usedDiscouragementParagraphs: "dailyHealthScore.usedDiscouragementParagraphs",
  usedMotivationParagraphs: "dailyHealthScore.usedMotivationParagraphs",
} as const;

export const PENDING_CORRECTION_KEY = "dailyHealthScore.pendingCorrection";
export const RECORD_RETENTION_DAYS = 90;

const DEFAULT_SETTINGS: UserSettings = {
  sleepGoal: 7.5,
  fiberGoal: 40,
};

const EMPTY_USED_SUGGESTIONS: UsedSuggestionsState = {
  sleep: [],
  fiber: [],
  exercise: [],
  maintain: [],
};

function safeParse<T>(raw: string | null, fallback: T): T {
  if (!raw) return fallback;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

export function loadSettings(): UserSettings {
  const parsed = safeParse<UserSettings | null>(
    localStorage.getItem(STORAGE_KEYS.settings),
    null,
  );
  if (!parsed || typeof parsed !== "object") return { ...DEFAULT_SETTINGS };
  const sleepGoal = parsed.sleepGoal;
  const fiberGoal = parsed.fiberGoal;
  if (![7, 7.5, 8].includes(sleepGoal as number)) return { ...DEFAULT_SETTINGS };
  if (![30, 40, 50].includes(fiberGoal as number)) return { ...DEFAULT_SETTINGS };
  return {
    sleepGoal: sleepGoal as UserSettings["sleepGoal"],
    fiberGoal: fiberGoal as UserSettings["fiberGoal"],
  };
}

export function saveSettings(settings: UserSettings): void {
  localStorage.setItem(STORAGE_KEYS.settings, JSON.stringify(settings));
  notifyRecordsUpdated();
}

export function getSyncToken(): string | null {
  const t = localStorage.getItem(SYNC_TOKEN_KEY);
  return t?.trim() || null;
}

export function setSyncToken(token: string | null): void {
  if (token == null || token.trim() === "") {
    localStorage.removeItem(SYNC_TOKEN_KEY);
    notifyRecordsUpdated();
    return;
  }
  localStorage.setItem(SYNC_TOKEN_KEY, token.trim());
  notifyRecordsUpdated();
}

export function loadRecords(): DailyRecord[] {
  const parsed = safeParse<unknown>(localStorage.getItem(STORAGE_KEYS.records), []);
  if (!Array.isArray(parsed)) return [];
  return parsed as DailyRecord[];
}

export function sortRecordsDesc(records: DailyRecord[]): DailyRecord[] {
  return [...records].sort((a, b) => b.date.localeCompare(a.date));
}

function trimToLatestDates(records: DailyRecord[], max = RECORD_RETENTION_DAYS): DailyRecord[] {
  const sorted = sortRecordsDesc(records);
  return sorted.slice(0, max);
}

export function saveDailyRecord(record: DailyRecord): void {
  const existing = loadRecords();
  const prev = existing.find((r) => r.date === record.date);
  const merged: DailyRecord = {
    ...record,
    createdAt: prev?.createdAt ?? record.createdAt,
    updatedAt: record.updatedAt,
  };
  const without = existing.filter((r) => r.date !== record.date);
  const next = trimToLatestDates([merged, ...without]);
  localStorage.setItem(STORAGE_KEYS.records, JSON.stringify(next));
  notifyRecordsUpdated();
}

export function exportRecordsAsJson(): string {
  return JSON.stringify(loadRecords(), null, 2);
}

export function clearAllLocalData(): void {
  localStorage.removeItem(STORAGE_KEYS.records);
  localStorage.removeItem(STORAGE_KEYS.settings);
  localStorage.removeItem(STORAGE_KEYS.usedSuggestions);
  localStorage.removeItem(STORAGE_KEYS.usedDiscouragementParagraphs);
  localStorage.removeItem(STORAGE_KEYS.usedMotivationParagraphs);
  sessionStorage.removeItem(PENDING_CORRECTION_KEY);
  notifyRecordsUpdated();
}

export function loadUsedSuggestions(): UsedSuggestionsState {
  const parsed = safeParse<Partial<UsedSuggestionsState> | null>(
    localStorage.getItem(STORAGE_KEYS.usedSuggestions),
    null,
  );
  if (!parsed || typeof parsed !== "object") return { ...EMPTY_USED_SUGGESTIONS };
  return {
    sleep: Array.isArray(parsed.sleep) ? parsed.sleep : [],
    fiber: Array.isArray(parsed.fiber) ? parsed.fiber : [],
    exercise: Array.isArray(parsed.exercise) ? parsed.exercise : [],
    maintain: Array.isArray(parsed.maintain) ? parsed.maintain : [],
  };
}

export function persistUsedSuggestions(state: UsedSuggestionsState): void {
  localStorage.setItem(STORAGE_KEYS.usedSuggestions, JSON.stringify(state));
}

export function loadUsedDiscouragementIds(): string[] {
  const parsed = safeParse<unknown>(
    localStorage.getItem(STORAGE_KEYS.usedDiscouragementParagraphs),
    [],
  );
  return Array.isArray(parsed) ? (parsed as string[]) : [];
}

export function loadUsedMotivationIds(): string[] {
  const parsed = safeParse<unknown>(
    localStorage.getItem(STORAGE_KEYS.usedMotivationParagraphs),
    [],
  );
  return Array.isArray(parsed) ? (parsed as string[]) : [];
}