import type { VercelRequest, VercelResponse } from "@vercel/node";
import type { RecordCompletionStatus } from "./types/health.js";
import { RECORD_RETENTION_DAYS } from "./_shared.js";
import { kvReady, loadTenant, resolveTenantFromRequest } from "./kv-tenant.js";
import { getDateKeysForRollingWindow, isValidDateKey, localDateKey } from "./lib/dates.js";

type SyncDate = {
  date: string;
  completionStatus: RecordCompletionStatus;
  reason: "today" | "missing" | "partial";
};

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!kvReady()) {
    res.status(503).json({ error: "Vercel KV is not configured." });
    return;
  }

  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const tenantInfo = resolveTenantFromRequest(req);
  if (tenantInfo.ok === false) {
    res.status(tenantInfo.status).json({ error: tenantInfo.error });
    return;
  }

  const requestedToday = Array.isArray(req.query.today)
    ? req.query.today[0]
    : req.query.today;
  const today = requestedToday && isValidDateKey(requestedToday)
    ? requestedToday
    : localDateKey();

  try {
    const tenant = await loadTenant(tenantInfo.prefix);
    const recordsByDate = new Map(tenant.records.map((record) => [record.date, record]));
    const dates = getDateKeysForRollingWindow(RECORD_RETENTION_DAYS, today);
    const syncDates: SyncDate[] = [];

    for (const date of dates) {
      const existing = recordsByDate.get(date);
      if (date === today) {
        syncDates.push({ date, completionStatus: "partial", reason: "today" });
      } else if (!existing) {
        syncDates.push({ date, completionStatus: "complete", reason: "missing" });
      } else if (existing.completionStatus !== "complete") {
        syncDates.push({ date, completionStatus: "complete", reason: "partial" });
      }
    }

    res.status(200).json({
      today,
      retentionDays: RECORD_RETENTION_DAYS,
      dates: syncDates,
    });
  } catch {
    res.status(500).json({ error: "Failed to calculate sync status." });
  }
}
