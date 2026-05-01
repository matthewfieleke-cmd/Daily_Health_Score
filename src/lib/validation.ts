import { isValidDateKey } from "./dates";
import type { ImportPayload } from "../types/health";

function parseNonNegativeNumber(raw: string | null): number | null {
  if (raw === null || raw.trim() === "") return null;
  const n = Number(raw);
  if (!Number.isFinite(n)) return null;
  if (n < 0) return null;
  return n;
}

export type ValidImportResult =
  | { ok: true; data: ImportPayload }
  | { ok: false };

/** Validates Apple Shortcut import query params. Zero values are valid here (handled upstream). */
export function validateImportParams(searchParams: URLSearchParams): ValidImportResult {
  const date = searchParams.get("date");
  if (!date || !isValidDateKey(date)) {
    return { ok: false };
  }

  const sleep = parseNonNegativeNumber(searchParams.get("sleep"));
  const fiber = parseNonNegativeNumber(searchParams.get("fiber"));
  const exercise = parseNonNegativeNumber(searchParams.get("exercise"));

  if (sleep === null || fiber === null || exercise === null) {
    return { ok: false };
  }

  return { ok: true, data: { date, sleep, fiber, exercise } };
}
