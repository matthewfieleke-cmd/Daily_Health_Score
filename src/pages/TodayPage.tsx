import { useMemo, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { useRecordsVersion } from "../context/records-version-context";
import { MetricCard } from "../components/MetricCard";
import { ScoreCard } from "../components/ScoreCard";
import { DiscouragementModal } from "../components/DiscouragementModal";
import { formatDisplayDate, localDateKey } from "../lib/dates";
import { primaryFocusLabel } from "../lib/display";
import { formatDisplayScore } from "../lib/scoring";
import { getNextDiscouragementParagraph } from "../lib/discouragement";
import { getNextMotivationParagraph } from "../lib/motivation";
import { loadRecords, sortRecordsDesc } from "../lib/storage";

type TodayLocationState = {
  importSaved?: { date: string; sleep: number; fiber: number; exercise: number };
};

export function TodayPage() {
  const location = useLocation();
  const [importBanner] = useState(() => {
    const s = location.state as TodayLocationState | null;
    return s?.importSaved ?? null;
  });
  const [importBannerDismissed, setImportBannerDismissed] = useState(false);
  const todayKey = localDateKey();
  const version = useRecordsVersion();
  const records = useMemo(() => {
    void version;
    return sortRecordsDesc(loadRecords());
  }, [version]);
  const todayRecord = records.find((r) => r.date === todayKey);
  const latest = records[0] ?? null;
  const display = todayRecord ?? latest;

  const [discOpen, setDiscOpen] = useState(false);
  const [discText, setDiscText] = useState<string | null>(null);
  const [motivOpen, setMotivOpen] = useState(false);
  const [motivText, setMotivText] = useState<string | null>(null);

  function openDiscouragement() {
    setDiscText(getNextDiscouragementParagraph());
    setDiscOpen(true);
  }

  function openMotivation() {
    setMotivText(getNextMotivationParagraph());
    setMotivOpen(true);
  }

  if (!display) {
    return (
      <div className="page-content home-empty">
        <section className="card home-empty-card">
          <img src="/DHS.png" alt="" className="home-empty-logo" />
          <h1 className="page-title home-empty-title">Daily Health Score</h1>
          <p className="muted home-empty-line">
            No data yet. Run your Shortcut, or{" "}
            <Link to="/settings">paste the import link</Link> in Settings.
          </p>
        </section>
      </div>
    );
  }

  const showingLatestInsteadOfToday = !todayRecord && latest;

  return (
    <div className="page-content">
      {showingLatestInsteadOfToday ? (
        <p className="callout callout--compact">No import for today yet.</p>
      ) : null}

      {importBanner && !importBannerDismissed ? (
        <div className="callout callout--compact import-flash" role="status">
          <p className="import-flash__copy">
            Saved <strong>{formatDisplayDate(importBanner.date)}</strong> with sleep{" "}
            <strong>{importBanner.sleep}</strong> hr, fiber <strong>{importBanner.fiber}</strong> g,
            exercise <strong>{importBanner.exercise}</strong> min. If sleep still does not match
            Apple Health, open <Link to="/settings">Settings</Link> and use{" "}
            <strong>Adjust a saved day</strong>, or change your Shortcut so the JSON or URL sends
            real hours as <code className="inline-code">sleepHours</code> (not a fixed placeholder
            in <code className="inline-code">sleep</code>).
          </p>
          <button
            type="button"
            className="btn-secondary"
            onClick={() => setImportBannerDismissed(true)}
          >
            Dismiss
          </button>
        </div>
      ) : null}

      <header className="today-header">
        <ScoreCard
          eyebrow={formatDisplayDate(display.date)}
          score={formatDisplayScore(display.totalScore)}
        />
        <div className="today-header-actions">
          <button type="button" className="btn-ghost" onClick={openDiscouragement}>
            Feeling discouraged?
          </button>
          <button type="button" className="btn-ghost" onClick={openMotivation}>
            Need motivation?
          </button>
        </div>
      </header>

      <section className="metric-grid">
        <MetricCard
          title="Sleep"
          summary={
            <>
              {display.sleepHours} hr → {formatDisplayScore(display.sleepScore)} / 4
            </>
          }
          fractionOfGoal={display.sleepHours / display.sleepGoal}
        />
        <MetricCard
          title="Fiber"
          summary={
            <>
              {display.fiberGrams} g → {formatDisplayScore(display.fiberScore)} / 4
            </>
          }
          fractionOfGoal={display.fiberGrams / display.fiberGoal}
        />
        <MetricCard
          title="Exercise"
          summary={
            <>
              {display.exerciseMinutes} min → {formatDisplayScore(display.exerciseScore)} / 2
            </>
          }
          fractionOfGoal={display.exerciseMinutes / display.exerciseGoal}
        />
      </section>

      <section className="card">
        <p className="eyebrow">Primary focus</p>
        <h2 className="section-title">{primaryFocusLabel(display.primaryFocus)}</h2>
        <p className="suggestion">{display.suggestion}</p>
      </section>

      <DiscouragementModal
        open={discOpen}
        text={discText}
        onClose={() => setDiscOpen(false)}
      />
      <DiscouragementModal
        open={motivOpen}
        text={motivText}
        title="Take responsibility"
        titleId="motiv-title"
        onClose={() => setMotivOpen(false)}
      />
    </div>
  );
}
