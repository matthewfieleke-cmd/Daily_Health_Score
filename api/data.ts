import type { VercelRequest, VercelResponse } from "@vercel/node";
import type { UserSettings } from "./types/health";
import { kvReady, loadTenant, resolveTenantFromRequest, saveTenant } from "./kv-tenant";

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!kvReady()) {
    res.status(503).json({ error: "Vercel KV is not configured." });
    return;
  }

  const tenantInfo = resolveTenantFromRequest(req);
  if (!tenantInfo.ok) {
    res.status(tenantInfo.status).json({ error: tenantInfo.error });
    return;
  }
  const { prefix } = tenantInfo;

  if (req.method === "GET") {
    try {
      const data = await loadTenant(prefix);
      res.status(200).json(data);
    } catch {
      res.status(500).json({ error: "Failed to read data." });
    }
    return;
  }

  if (req.method === "PUT") {
    try {
      const body =
        typeof req.body === "object" && req.body !== null
          ? (req.body as Partial<UserSettings>)
          : {};
      const sleepGoal = body.sleepGoal;
      const fiberGoal = body.fiberGoal;
      if (
        ![7, 7.5, 8].includes(sleepGoal as number) ||
        ![30, 40, 50].includes(fiberGoal as number)
      ) {
        res.status(400).json({ error: "Invalid settings payload." });
        return;
      }
      const tenant = await loadTenant(prefix);
      tenant.settings = {
        sleepGoal: sleepGoal as UserSettings["sleepGoal"],
        fiberGoal: fiberGoal as UserSettings["fiberGoal"],
      };
      await saveTenant(prefix, tenant);
      res.status(200).json({ ok: true, settings: tenant.settings });
    } catch {
      res.status(500).json({ error: "Failed to save settings." });
    }
    return;
  }

  res.setHeader("Allow", "GET, PUT");
  res.status(405).json({ error: "Method not allowed" });
}
