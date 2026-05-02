import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useEffect } from "react";
import { applyImportPayload } from "../lib/cloud-sync";
import { validateImportParams } from "../lib/validation";
import { PENDING_CORRECTION_KEY } from "../lib/storage";

type ImportDestination = {
  to: "/today" | "/invalid-import" | "/correct-import";
  state?: unknown;
};

const importRuns = new Map<string, Promise<ImportDestination>>();

async function processImport(searchParams: URLSearchParams): Promise<ImportDestination> {
  const result = validateImportParams(searchParams);
  if (!result.ok) {
    return { to: "/invalid-import" };
  }

  const { date, sleep, fiber, exercise } = result.data;
  if (sleep === 0 || fiber === 0 || exercise === 0) {
    sessionStorage.setItem(
      PENDING_CORRECTION_KEY,
      JSON.stringify({ date, sleep, fiber, exercise }),
    );
    return { to: "/correct-import", state: result.data };
  }

  await applyImportPayload(result.data);
  return { to: "/today" };
}

export function ImportPage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();

  useEffect(() => {
    let cancelled = false;
    const qs = searchParams.toString();
    const existingRun = importRuns.get(qs);
    const run = existingRun ?? processImport(new URLSearchParams(searchParams));
    if (!existingRun) {
      importRuns.set(qs, run);
      run.finally(() => {
        window.setTimeout(() => importRuns.delete(qs), 0);
      });
    }

    void (async () => {
      const destination = await run;
      if (!cancelled) {
        navigate(destination.to, { replace: true, state: destination.state });
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [navigate, searchParams]);

  return (
    <div className="page-narrow">
      <p className="muted">Processing import…</p>
      <Link to="/today" className="text-link">
        Go to Today
      </Link>
    </div>
  );
}
