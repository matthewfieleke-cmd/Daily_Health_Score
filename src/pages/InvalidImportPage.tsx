import { Link } from "react-router-dom";

export function InvalidImportPage() {
  return (
    <div className="page-narrow">
      <h1 className="page-title">Invalid import data.</h1>
      <p className="lede">
        The URL did not include valid numeric values and a date in{" "}
        <code className="inline-code">yyyy-MM-dd</code> format.
      </p>
      <p className="muted">Expected format:</p>
      <pre className="code-block">
        /import?date=2026-05-01&amp;sleep=7.4&amp;fiber=38&amp;exercise=28
      </pre>
      <Link to="/today" className="btn-primary inline-btn">
        Back to Today
      </Link>
    </div>
  );
}
