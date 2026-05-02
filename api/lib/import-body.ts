import { isValidDateKey } from "./dates.js";
import type { ImportPayload } from "../types/health.js";

function parseNonNegativeNumber(raw: unknown): number | null {
  const n = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(n)) return null;
  if (n < 0) return null;
  return n;
}

export type BodyImportResult =
  | { ok: true; data: ImportPayload }
  | { ok: false };

/** Validates JSON body from Shortcut POST / manual sync. Zeros allowed here (caller may reject). */
export function validateImportBody(body: unknown): BodyImportResult {
  if (!body || typeof body !== "object") return { ok: false };
  const o = body as Record<string, unknown>;
  const date = o.date;
  if (typeof date !== "string" || !isValidDateKey(date)) {
    return { ok: false };
  }
  const sleep = parseNonNegativeNumber(o.sleep);
  const fiber = parseNonNegativeNumber(o.fiber);
  const exercise = parseNonNegativeNumber(o.exercise);
  if (sleep === null || fiber === null || exercise === null) {
    return { ok: false };
  }
  const completionStatus =
    o.completionStatus === "partial" || o.completionStatus === "complete"
      ? o.completionStatus
      : undefined;
  return { ok: true, data: { date, sleep, fiber, exercise, completionStatus } };
}
