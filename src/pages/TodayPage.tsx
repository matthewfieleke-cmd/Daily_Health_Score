import { useState } from "react";
import { Link } from "react-router-dom";
import { MetricCard } from "../components/MetricCard";
import { ScoreCard } from "../components/ScoreCard";
import { DiscouragementModal } from "../components/DiscouragementModal";
import { formatDisplayDate, localDateKey } from "../lib/dates";
import { primaryFocusLabel } from "../lib/display";
import { formatDisplayScore } from "../lib/scoring";
import { getNextDiscouragementParagraph } from "../lib/discouragement";
import { loadRecords, sortRecordsDesc } from "../lib/storage";

export function TodayPage() {
  const todayKey = localDateKey();
  const records = sortRecordsDesc(loadRecords());
  const todayRecord = records.find((r) => r.date === todayKey);
  const latest = records[0] ?? null;
  const display = todayRecord ?? latest;

  const [discOpen, setDiscOpen] = useState(false);
  const [discText, setDiscText] = useState<string | null>(null);

  function openDiscouragement() {
    setDiscText(getNextDiscouragementParagraph());
    setDiscOpen(true);
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

      <header className="today-header">
        <ScoreCard
          eyebrow={formatDisplayDate(display.date)}
          score={formatDisplayScore(display.totalScore)}
        />
        <button type="button" className="btn-ghost" onClick={openDiscouragement}>
          Feeling discouraged?
        </button>
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
    </div>
  );
}
