import type { ReactNode } from "react";
import { ProgressBar } from "./ProgressBar";

type MetricCardProps = {
  title: string;
  summary: ReactNode;
  fractionOfGoal: number;
};

export function MetricCard({ title, summary, fractionOfGoal }: MetricCardProps) {
  return (
    <article className="metric-card">
      <header className="metric-card__head">
        <h3>{title}</h3>
        <div className="metric-card__summary">{summary}</div>
      </header>
      <ProgressBar fraction={fractionOfGoal} label={`${title} progress toward goal`} />
    </article>
  );
}
