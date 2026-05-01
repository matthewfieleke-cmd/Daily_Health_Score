import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useEffect } from "react";
import { applyImportPayload } from "../lib/cloud-sync";
import { validateImportParams } from "../lib/validation";
import { PENDING_CORRECTION_KEY } from "../lib/storage";

let lastHandledImportQuery = "";

export function ImportPage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();

  useEffect(() => {
    let cancelled = false;
    const qs = searchParams.toString();
    if (qs === lastHandledImportQuery) return;
    lastHandledImportQuery = qs;

    void (async () => {
      const result = validateImportParams(searchParams);
      if (!result.ok) {
        if (!cancelled) navigate("/invalid-import", { replace: true });
        return;
      }

      const { date, sleep, fiber, exercise } = result.data;
      if (sleep === 0 || fiber === 0 || exercise === 0) {
        sessionStorage.setItem(
          PENDING_CORRECTION_KEY,
          JSON.stringify({ date, sleep, fiber, exercise }),
        );
        if (!cancelled) {
          navigate("/correct-import", { replace: true, state: result.data });
        }
        return;
      }

      await applyImportPayload(result.data);
      if (!cancelled) navigate("/today", { replace: true });
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
