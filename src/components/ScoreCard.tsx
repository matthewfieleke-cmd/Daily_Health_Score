type ScoreCardProps = {
  /** Already localized title text shown above the score */
  eyebrow: string;
  /** Formatted numeric portion before `/ 10` */
  score: string;
};

export function ScoreCard({ eyebrow, score }: ScoreCardProps) {
  return (
    <div>
      <p className="eyebrow">{eyebrow}</p>
      <h1 className="score-hero">
        {score}
        <span className="score-hero__suffix"> / 10</span>
      </h1>
    </div>
  );
}
