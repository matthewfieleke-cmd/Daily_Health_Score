import type { FormEvent } from "react";
import { useMemo, useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import type { ImportPayload } from "../types/health";
import { buildDailyRecord } from "../lib/record";
import { loadSettings, PENDING_CORRECTION_KEY, saveDailyRecord } from "../lib/storage";

function loadPending(): ImportPayload | null {
  const raw = sessionStorage.getItem(PENDING_CORRECTION_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as ImportPayload;
  } catch {
    return null;
  }
}

export function ManualCorrectionPage() {
  const location = useLocation();
  const navigate = useNavigate();
  const fromState = location.state as ImportPayload | null | undefined;

  const initial = useMemo(() => {
    if (fromState && typeof fromState === "object" && "date" in fromState) {
      return fromState;
    }
    return loadPending();
  }, [fromState]);

  const [sleep, setSleep] = useState<string>("");
  const [fiber, setFiber] = useState<string>("");
  const [exercise, setExercise] = useState<string>("");
  const [error, setError] = useState<string | null>(null);

  if (!initial) {
    return (
      <div className="page-narrow">
        <h1 className="page-title">Nothing to correct</h1>
        <p className="muted">Return home and run your Shortcut import again.</p>
        <Link to="/today" className="btn-primary inline-btn">
          Back to Today
        </Link>
      </div>
    );
  }

  const needSleep = initial.sleep === 0;
  const needFiber = initial.fiber === 0;
  const needExercise = initial.exercise === 0;

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);

    const nextSleep = needSleep ? Number(sleep) : initial.sleep;
    const nextFiber = needFiber ? Number(fiber) : initial.fiber;
    const nextExercise = needExercise ? Number(exercise) : initial.exercise;

    if (needSleep && (!Number.isFinite(nextSleep) || nextSleep <= 0)) {
      setError("Sleep hours must be greater than 0.");
      return;
    }
    if (needFiber && (!Number.isFinite(nextFiber) || nextFiber <= 0)) {
      setError("Fiber grams must be greater than 0.");
      return;
    }
    if (needExercise && (!Number.isFinite(nextExercise) || nextExercise <= 0)) {
      setError("Exercise minutes must be greater than 0.");
      return;
    }

    const settings = loadSettings();
    const record = buildDailyRecord(
      {
        date: initial.date,
        sleepHours: nextSleep,
        fiberGrams: nextFiber,
        exerciseMinutes: nextExercise,
      },
      settings,
    );
    saveDailyRecord(record);
    sessionStorage.removeItem(PENDING_CORRECTION_KEY);
    navigate("/today", { replace: true });
  }

  return (
    <div className="page-narrow">
      <h1 className="page-title">
        Some values imported as 0. Please correct them before saving.
      </h1>
      <p className="muted">
        Date: <strong>{initial.date}</strong>
      </p>

      <form className="stack-form" onSubmit={handleSubmit}>
        {needSleep ? (
          <label className="field">
            <span>Sleep (hours)</span>
            <input
              type="number"
              step="0.1"
              min={0.1}
              required
              value={sleep}
              onChange={(ev) => setSleep(ev.target.value)}
            />
          </label>
        ) : null}

        {needFiber ? (
          <label className="field">
            <span>Fiber (grams)</span>
            <input
              type="number"
              step="0.1"
              min={0.1}
              required
              value={fiber}
              onChange={(ev) => setFiber(ev.target.value)}
            />
          </label>
        ) : null}

        {needExercise ? (
          <label className="field">
            <span>Exercise (minutes)</span>
            <input
              type="number"
              step="0.1"
              min={0.1}
              required
              value={exercise}
              onChange={(ev) => setExercise(ev.target.value)}
            />
          </label>
        ) : null}

        {error ? <p className="error-text">{error}</p> : null}

        <button type="submit" className="btn-primary">
          Save corrected day
        </button>
      </form>

      <p className="muted">
        <Link to="/today" className="text-link">
          Cancel and go to Today
        </Link>
      </p>
    </div>
  );
}
