import type { DailyRecord } from "../types/health";
import { formatDisplayDate } from "../lib/dates";
import { formatDisplayScore } from "../lib/scoring";

type DailyRecordListProps = {
  records: DailyRecord[];
  defaultOpen?: boolean;
};

export function DailyRecordList({
  records,
  defaultOpen = false,
}: DailyRecordListProps) {
  return (
    <details className="record-list" open={defaultOpen}>
      <summary className="record-list__summary">Daily breakdown</summary>
      <ul className="record-list__items">
        {records.map((r) => (
          <li key={r.date} className="record-list__row">
            <div className="record-list__date">{formatDisplayDate(r.date)}</div>
            <div className="record-list__stats">
              Score {formatDisplayScore(r.totalScore)} / 10 · Sleep {r.sleepHours} hr · Fiber{" "}
              {r.fiberGrams} g · Exercise {r.exerciseMinutes} min
            </div>
          </li>
        ))}
      </ul>
    </details>
  );
}
