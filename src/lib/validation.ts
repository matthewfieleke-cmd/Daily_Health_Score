import { isValidDateKey } from "./dates";
import type { ImportPayload } from "../types/health";

function parseNonNegativeNumber(raw: string | null): number | null {
  if (raw === null || raw.trim() === "") return null;
  const n = Number(raw);
  if (!Number.isFinite(n)) return null;
  if (n < 0) return null;
  return n;
}

/**
 * When a query key appears more than once, `URLSearchParams.get` returns the *first* value (Web IDL).
 * Apple Shortcuts sometimes produce URLs where a template `sleep=…` is followed by the real value;
 * using the last entry matches that intent and matches JSON bodies where duplicate keys last-wins.
 */
function lastQueryValue(searchParams: URLSearchParams, name: string): string | null {
  const values = searchParams.getAll(name);
  if (values.length === 0) return null;
  const last = values[values.length - 1]?.trim();
  if (!last) return null;
  return last;
}

export type ValidImportResult =
  | { ok: true; data: ImportPayload }
  | { ok: false };

/** Validates Apple Shortcut import query params. Zero values are valid here (handled upstream). */
export function validateImportParams(searchParams: URLSearchParams): ValidImportResult {
  const date = lastQueryValue(searchParams, "date");
  if (!date || !isValidDateKey(date)) {
    return { ok: false };
  }

  const sleep = parseNonNegativeNumber(lastQueryValue(searchParams, "sleep"));
  const fiber = parseNonNegativeNumber(lastQueryValue(searchParams, "fiber"));
  const exercise = parseNonNegativeNumber(lastQueryValue(searchParams, "exercise"));

  if (sleep === null || fiber === null || exercise === null) {
    return { ok: false };
  }

  return { ok: true, data: { date, sleep, fiber, exercise } };
}
