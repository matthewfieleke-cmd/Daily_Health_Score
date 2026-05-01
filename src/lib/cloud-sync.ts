import type { ImportPayload, UsedSuggestionsState, UserSettings } from "../types/health";
import { buildDailyRecord } from "./record";
import {
  STORAGE_KEYS,
  getSyncToken,
  loadSettings,
  saveDailyRecord,
} from "./storage";
import { notifyRecordsUpdated } from "./storage-events";

function isUsedSuggestionsState(v: unknown): v is UsedSuggestionsState {
  if (!v || typeof v !== "object") return false;
  const o = v as Record<string, unknown>;
  return (
    Array.isArray(o.sleep) &&
    Array.isArray(o.fiber) &&
    Array.isArray(o.exercise) &&
    Array.isArray(o.maintain)
  );
}

function isValidSettings(v: unknown): v is UserSettings {
  if (!v || typeof v !== "object") return false;
  const o = v as UserSettings;
  return (
    [7, 7.5, 8].includes(o.sleepGoal as number) &&
    [30, 40, 50].includes(o.fiberGoal as number)
  );
}

/** Pull server state into localStorage. Returns true if remote data was applied. */
export async function pullCloudIntoLocal(): Promise<boolean> {
  const token = getSyncToken();
  if (!token) return false;
  try {
    const res = await fetch(`${window.location.origin}/api/data`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) return false;
    const body = (await res.json()) as {
      records?: unknown;
      settings?: unknown;
      usedSuggestions?: unknown;
    };
    if (!Array.isArray(body.records) || !isValidSettings(body.settings)) {
      return false;
    }
    if (!isUsedSuggestionsState(body.usedSuggestions)) {
      return false;
    }
    localStorage.setItem(STORAGE_KEYS.records, JSON.stringify(body.records));
    localStorage.setItem(STORAGE_KEYS.settings, JSON.stringify(body.settings));
    localStorage.setItem(
      STORAGE_KEYS.usedSuggestions,
      JSON.stringify(body.usedSuggestions),
    );
    notifyRecordsUpdated();
    return true;
  } catch {
    return false;
  }
}

export async function pushRemoteSettings(settings: UserSettings): Promise<boolean> {
  const token = getSyncToken();
  if (!token) return false;
  try {
    const res = await fetch(`${window.location.origin}/api/data`, {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(settings),
    });
    return res.ok;
  } catch {
    return false;
  }
}

/** Same payload shape as the Apple Shortcut / client import. */
export async function pushRemoteIngest(payload: ImportPayload): Promise<boolean> {
  const token = getSyncToken();
  if (!token) return false;
  try {
    const res = await fetch(`${window.location.origin}/api/ingest`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        date: payload.date,
        sleep: payload.sleep,
        fiber: payload.fiber,
        exercise: payload.exercise,
      }),
    });
    return res.ok;
  } catch {
    return false;
  }
}

/** Prefer server ingest + pull when a sync token exists; otherwise save locally. */
export async function applyImportPayload(payload: ImportPayload): Promise<void> {
  const token = getSyncToken();
  if (token) {
    const ok = await pushRemoteIngest(payload);
    if (ok) {
      await pullCloudIntoLocal();
      return;
    }
  }
  const settings = loadSettings();
  const record = buildDailyRecord(
    {
      date: payload.date,
      sleepHours: payload.sleep,
      fiberGrams: payload.fiber,
      exerciseMinutes: payload.exercise,
    },
    settings,
  );
  saveDailyRecord(record);
}
