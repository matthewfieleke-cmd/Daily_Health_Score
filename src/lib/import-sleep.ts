const SLEEP_KEYS = ["sleepHours", "timeAsleep", "asleepHours", "sleep"] as const;

export type SleepKey = (typeof SLEEP_KEYS)[number];

export function parseNonNegativeNumber(raw: unknown): number | null {
  const n = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(n)) return null;
  if (n < 0) return null;
  return n;
}

function firstPresentSleepValue(values: Partial<Record<SleepKey, number>>): number | null {
  for (const key of SLEEP_KEYS) {
    const v = values[key];
    if (v !== undefined) return v;
  }
  return null;
}

/**
 * When Shortcuts send both `sleepHours` (often a copied template) and `sleep` (often the live
 * AutoSleep variable), pick the value that actually changed vs the last saved night.
 */
export function resolveSleepHours(
  values: Partial<Record<SleepKey, number>>,
  lastSavedSleepHours?: number,
): number | null {
  const present = SLEEP_KEYS.filter((k) => values[k] !== undefined);
  if (present.length === 0) return null;
  if (present.length === 1) return values[present[0]!]!;

  const sleep = values.sleep;
  const sleepHours = values.sleepHours;

  if (
    sleep !== undefined &&
    sleepHours !== undefined &&
    sleep !== sleepHours &&
    lastSavedSleepHours !== undefined
  ) {
    if (sleepHours === lastSavedSleepHours && sleep !== lastSavedSleepHours) {
      return sleep;
    }
    if (sleep === lastSavedSleepHours && sleepHours !== lastSavedSleepHours) {
      return sleepHours;
    }
  }

  if (sleep !== undefined && sleepHours !== undefined && sleep !== sleepHours) {
    return sleep;
  }

  return firstPresentSleepValue(values);
}

export function collectSleepValuesFromObject(
  o: Record<string, unknown>,
): Partial<Record<SleepKey, number>> {
  const out: Partial<Record<SleepKey, number>> = {};
  for (const key of SLEEP_KEYS) {
    if (!Object.prototype.hasOwnProperty.call(o, key)) continue;
    const raw = o[key];
    if (raw === undefined || raw === null) continue;
    const n = parseNonNegativeNumber(raw);
    if (n !== null) out[key] = n;
  }
  return out;
}

export function collectSleepValuesFromQuery(
  getValue: (name: string) => string | null,
): Partial<Record<SleepKey, number>> {
  const out: Partial<Record<SleepKey, number>> = {};
  for (const key of SLEEP_KEYS) {
    const raw = getValue(key);
    if (raw === null) continue;
    const n = parseNonNegativeNumber(raw);
    if (n !== null) out[key] = n;
  }
  return out;
}

/** Most recent saved sleep for this import date (same day overwrite or prior night). */
export function lastSavedSleepHoursForDate(
  records: { date: string; sleepHours: number }[],
  forDate: string,
): number | undefined {
  const sorted = [...records].sort((a, b) => b.date.localeCompare(a.date));
  const sameDay = sorted.find((r) => r.date === forDate);
  if (sameDay) return sameDay.sleepHours;
  const prior = sorted.find((r) => r.date < forDate);
  if (prior) return prior.sleepHours;
  return sorted[0]?.sleepHours;
}
