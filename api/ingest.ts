import type { VercelRequest, VercelResponse } from "@vercel/node";
import { calculateScore, determinePrimaryFocus } from "./lib/scoring";
import { composeDailyRecord } from "./lib/record-compose";
import { advanceSuggestion } from "./lib/suggestion-engine";
import { validateImportBody } from "./lib/import-body";
import { kvReady, loadTenant, resolveTenantFromRequest, saveTenant } from "./kv-tenant";
import { trimRecords } from "./_shared";

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!kvReady()) {
    res.status(503).json({ error: "Vercel KV is not configured." });
    return;
  }

  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const tenantInfo = resolveTenantFromRequest(req);
  if (!tenantInfo.ok) {
    res.status(tenantInfo.status).json({ error: tenantInfo.error });
    return;
  }
  const { prefix } = tenantInfo;

  const rawBody =
    typeof req.body === "object" && req.body !== null ? req.body : undefined;
  const parsed = validateImportBody(rawBody);
  if (!parsed.ok) {
    res.status(400).json({ error: "Invalid import body." });
    return;
  }

  const { date, sleep, fiber, exercise } = parsed.data;
  if (sleep === 0 || fiber === 0 || exercise === 0) {
    res.status(400).json({
      error:
        "Zeros are not accepted via API. Correct values in the app or adjust your Shortcut.",
    });
    return;
  }

  try {
    const tenant = await loadTenant(prefix);
    const settings = tenant.settings;
    const computed = calculateScore(
      {
        sleepHours: sleep,
        fiberGrams: fiber,
        exerciseMinutes: exercise,
      },
      settings,
    );
    const primaryFocus = determinePrimaryFocus({
      sleepPercent: computed.sleepPercent,
      fiberPercent: computed.fiberPercent,
      exercisePercent: computed.exercisePercent,
    });
    const { text, nextState } = advanceSuggestion(primaryFocus, tenant.usedSuggestions);
    const draft = composeDailyRecord(
      {
        date,
        sleepHours: sleep,
        fiberGrams: fiber,
        exerciseMinutes: exercise,
      },
      settings,
      computed,
      primaryFocus,
      text,
      new Date(),
    );

    const prev = tenant.records.find((r) => r.date === date);
    const nowIso = new Date().toISOString();
    const merged = {
      ...draft,
      createdAt: prev?.createdAt ?? draft.createdAt,
      updatedAt: nowIso,
    };

    const without = tenant.records.filter((r) => r.date !== date);
    tenant.records = trimRecords([merged, ...without], 30);
    tenant.usedSuggestions = nextState;

    await saveTenant(prefix, tenant);
    res.status(200).json({ ok: true, record: merged });
  } catch {
    res.status(500).json({ error: "Failed to save ingest." });
  }
}
