import { getDateKeysForRollingWindow } from "../lib/dates";
import { getRollingAverages } from "../lib/averages";
import { loadRecords } from "../lib/storage";
import { formatDisplayScore } from "../lib/scoring";
import { DailyRecordList } from "../components/DailyRecordList";

export function WeekPage() {
  const records = loadRecords();
  const keys = getDateKeysForRollingWindow(7);
  const stats = getRollingAverages(records, keys);

  if (!stats) {
    return (
      <div className="page-content">
        <p className="muted">No records in the last 7 days yet.</p>
      </div>
    );
  }

  return (
    <div className="page-content">
      <header className="section-head">
        <h1 className="page-title">7-Day view</h1>
        <p className="muted">
          Based on {stats.daysWithData} of the last {stats.daysInWindow} days.
        </p>
      </header>

      <section className="stats-grid card">
        <div>
          <p className="eyebrow">Average total score</p>
          <p className="stat-number">{formatDisplayScore(stats.avgTotalScore)} / 10</p>
        </div>
        <div>
          <p className="eyebrow">Average sleep</p>
          <p className="stat-number">{formatDisplayScore(stats.avgSleepHours)} hr</p>
        </div>
        <div>
          <p className="eyebrow">Average fiber</p>
          <p className="stat-number">{formatDisplayScore(stats.avgFiberGrams)} g</p>
        </div>
        <div>
          <p className="eyebrow">Average exercise</p>
          <p className="stat-number">{formatDisplayScore(stats.avgExerciseMinutes)} min</p>
        </div>
        <div>
          <p className="eyebrow">Avg sleep sub-score</p>
          <p className="stat-number">{formatDisplayScore(stats.avgSleepScore)} / 4</p>
        </div>
        <div>
          <p className="eyebrow">Avg fiber sub-score</p>
          <p className="stat-number">{formatDisplayScore(stats.avgFiberScore)} / 4</p>
        </div>
        <div>
          <p className="eyebrow">Avg exercise sub-score</p>
          <p className="stat-number">{formatDisplayScore(stats.avgExerciseScore)} / 2</p>
        </div>
      </section>

      <DailyRecordList records={stats.recordsInWindow} />
    </div>
  );
}
