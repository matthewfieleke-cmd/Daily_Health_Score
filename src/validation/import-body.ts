import { isValidDateKey } from "../lib/dates";
import type { ImportPayload } from "../types/health";

function parseNonNegativeNumber(raw: unknown): number | null {
  const n = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(n)) return null;
  if (n < 0) return null;
  return n;
}

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

/** Validates JSON body from Shortcut POST / manual sync. Zeros allowed here (caller may reject). */
export function validateImportBody(body: unknown): BodyImportResult {
  if (!body || typeof body !== "object") return { ok: false };
  const o = body as Record<string, unknown>;
  const date = o.date;
  if (typeof date !== "string" || !isValidDateKey(date)) {
    return { ok: false };
  }
  const sleep = firstParsedBodyMetric(o, [
    "sleepHours",
    "timeAsleep",
    "asleepHours",
    "sleep",
  ]);
  const fiber = firstParsedBodyMetric(o, ["fiberGrams", "dietaryFiber", "fiber"]);
  const exercise = firstParsedBodyMetric(o, ["exerciseMinutes", "exercise"]);
  if (sleep === null || fiber === null || exercise === null) {
    return { ok: false };
  }
  return { ok: true, data: { date, sleep, fiber, exercise } };
}
