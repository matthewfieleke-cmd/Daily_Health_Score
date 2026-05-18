import { isValidDateKey } from "./dates.js";
import type { ImportPayload } from "../types/health.js";
import {
  collectSleepValuesFromObject,
  parseNonNegativeNumber,
  resolveSleepHours,
} from "./import-sleep.js";

export type BodyImportResult =
  | { ok: true; data: ImportPayload }
  | { ok: false };

function firstParsedBodyMetric(
  o: Record<string, unknown>,
  keys: readonly string[],
): number | null {
  for (const key of keys) {
    if (!Object.prototype.hasOwnProperty.call(o, key)) continue;
    const raw = o[key];
    if (raw === undefined || raw === null) continue;
    const n = parseNonNegativeNumber(raw);
    if (n !== null) return n;
  }
  return null;
}

export type ImportBodyOptions = {
  lastSavedSleepHours?: number;
};

/** Validates JSON body from Shortcut POST / manual sync. Zeros allowed here (caller may reject). */
export function validateImportBody(
  body: unknown,
  options: ImportBodyOptions = {},
): BodyImportResult {
  if (!body || typeof body !== "object") return { ok: false };
  const o = body as Record<string, unknown>;
  const date = o.date;
  if (typeof date !== "string" || !isValidDateKey(date)) {
    return { ok: false };
  }
  const sleep = resolveSleepHours(
    collectSleepValuesFromObject(o),
    options.lastSavedSleepHours,
  );
  const fiber = firstParsedBodyMetric(o, ["fiberGrams", "dietaryFiber", "fiber"]);
  const exercise = firstParsedBodyMetric(o, ["exerciseMinutes", "exercise"]);
  if (sleep === null || fiber === null || exercise === null) {
    return { ok: false };
  }
  const completionStatus =
    o.completionStatus === "partial" || o.completionStatus === "complete"
      ? o.completionStatus
      : undefined;
  return { ok: true, data: { date, sleep, fiber, exercise, completionStatus } };
}
