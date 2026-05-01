import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useEffect } from "react";
import { validateImportParams } from "../lib/validation";
import {
  loadSettings,
  PENDING_CORRECTION_KEY,
  saveDailyRecord,
} from "../lib/storage";
import { buildDailyRecord } from "../lib/record";

let lastHandledImportQuery = "";

export function ImportPage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();

  useEffect(() => {
    const qs = searchParams.toString();
    if (qs === lastHandledImportQuery) return;
    lastHandledImportQuery = qs;

    const result = validateImportParams(searchParams);
    if (!result.ok) {
      navigate("/invalid-import", { replace: true });
      return;
    }

    const { date, sleep, fiber, exercise } = result.data;
    if (sleep === 0 || fiber === 0 || exercise === 0) {
      sessionStorage.setItem(
        PENDING_CORRECTION_KEY,
        JSON.stringify({ date, sleep, fiber, exercise }),
      );
      navigate("/correct-import", { replace: true, state: result.data });
      return;
    }

    const settings = loadSettings();
    const record = buildDailyRecord(
      {
        date,
        sleepHours: sleep,
        fiberGrams: fiber,
        exerciseMinutes: exercise,
      },
      settings,
    );
    saveDailyRecord(record);
    navigate("/today", { replace: true });
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
