type ProgressBarProps = {
  fraction: number;
  label?: string;
};

/** Progress toward goal (0–1+); bar visually caps at 100%. */
export function ProgressBar({ fraction, label }: ProgressBarProps) {
  const pct = Math.min(100, Math.max(0, fraction * 100));
  return (
    <>
      {label ? <span className="sr-only">{label}</span> : null}
      <div
        className="progress-track"
        role="progressbar"
        aria-valuenow={Math.round(pct)}
        aria-valuemin={0}
        aria-valuemax={100}
      >
        <div className="progress-fill" style={{ width: `${pct}%` }} />
      </div>
    </>
  );
}
