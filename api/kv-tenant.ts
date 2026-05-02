import { kv } from "@vercel/kv";
import type { VercelRequest } from "@vercel/node";
import type {
  DailyRecord,
  UsedSuggestionsState,
  UserSettings,
} from "./types/health";
import {
  DEFAULT_SETTINGS,
  EMPTY_USED,
  parseBearer,
  safePrefix,
} from "./_shared";

export function kvReady(): boolean {
  return Boolean(process.env.KV_REST_API_URL && process.env.KV_REST_API_TOKEN);
}

export async function loadTenant(prefix: string): Promise<{
  records: DailyRecord[];
  settings: UserSettings;
  usedSuggestions: UsedSuggestionsState;
}> {
  const [recordsRaw, settingsRaw, usedRaw] = await Promise.all([
    kv.get<DailyRecord[]>(`${prefix}:records`),
    kv.get<UserSettings>(`${prefix}:settings`),
    kv.get<UsedSuggestionsState>(`${prefix}:usedSuggestions`),
  ]);
  const records = Array.isArray(recordsRaw) ? recordsRaw : [];
  const settings =
    settingsRaw &&
    typeof settingsRaw === "object" &&
    [7, 7.5, 8].includes(settingsRaw.sleepGoal as number) &&
    [30, 40, 50].includes(settingsRaw.fiberGoal as number)
      ? settingsRaw
      : { ...DEFAULT_SETTINGS };
  const usedSuggestions =
    usedRaw &&
    typeof usedRaw === "object" &&
    Array.isArray((usedRaw as UsedSuggestionsState).sleep)
      ? (usedRaw as UsedSuggestionsState)
      : { ...EMPTY_USED };
  return { records, settings, usedSuggestions };
}

export async function saveTenant(
  prefix: string,
  data: {
    records: DailyRecord[];
    settings: UserSettings;
    usedSuggestions: UsedSuggestionsState;
  },
): Promise<void> {
  await Promise.all([
    kv.set(`${prefix}:records`, data.records),
    kv.set(`${prefix}:settings`, data.settings),
    kv.set(`${prefix}:usedSuggestions`, data.usedSuggestions),
  ]);
}

export type TenantResolution =
  | { ok: true; prefix: string }
  | { ok: false; status: number; error: string };

export function resolveTenantFromRequest(req: VercelRequest): TenantResolution {
  const token = parseBearer(req.headers.authorization);
  if (!token) {
    return { ok: false, status: 401, error: "Missing Authorization Bearer token." };
  }
  try {
    return { ok: true, prefix: safePrefix(token) };
  } catch {
    return { ok: false, status: 401, error: "Invalid token." };
  }
}
