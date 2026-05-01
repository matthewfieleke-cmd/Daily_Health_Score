import type { FormEvent } from "react";
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import type { FiberGoalGrams, SleepGoalHours } from "../types/health";
import { localDateKey } from "../lib/dates";
import { parseImportUrlToSearch } from "../lib/import-url";
import {
  clearAllLocalData,
  exportRecordsAsJson,
  loadSettings,
  saveSettings,
} from "../lib/storage";

const sleepOptions: SleepGoalHours[] = [7, 7.5, 8];
const fiberOptions: FiberGoalGrams[] = [30, 40, 50];

export function SettingsPage() {
  const navigate = useNavigate();
  const [settings, setSettings] = useState(loadSettings);
  const [pastedImportUrl, setPastedImportUrl] = useState("");
  const baseUrl =
    typeof window !== "undefined"
      ? window.location.origin
      : "https://YOUR-VERCEL-APP.vercel.app";

  function updateSleep(goal: SleepGoalHours) {
    const next = { ...settings, sleepGoal: goal };
    setSettings(next);
    saveSettings(next);
  }

  function updateFiber(goal: FiberGoalGrams) {
    const next = { ...settings, fiberGoal: goal };
    setSettings(next);
    saveSettings(next);
  }

  function handleExport() {
    const blob = new Blob([exportRecordsAsJson()], {
      type: "application/json",
    });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `daily-health-score-export-${localDateKey()}.json`;
    anchor.click();
    URL.revokeObjectURL(url);
  }

  function handleClear() {
    const confirmed = window.confirm(
      "Erase all local Daily Health Score data? This cannot be undone.",
    );
    if (!confirmed) return;
    clearAllLocalData();
    setSettings(loadSettings());
    window.alert("Local data cleared.");
  }

  function handlePastedImport(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const search = parseImportUrlToSearch(pastedImportUrl);
    if (!search) {
      window.alert(
        "Paste a full URL that ends in /import and includes date, sleep, fiber, and exercise parameters.",
      );
      return;
    }
    setPastedImportUrl("");
    navigate(`/import${search}`);
  }

  const sampleUrl = `${baseUrl}/import?date=2026-05-01&sleep=7.4&fiber=38&exercise=28`;
  const templateUrl = `${baseUrl}/import?date=yyyy-MM-dd&sleep=[sleep]&fiber=[fiber]&exercise=[exercise]`;

  return (
    <div className="page-content">
      <h1 className="page-title">Settings</h1>

      <section className="card stack-gap">
        <h2 className="section-title">Goals</h2>
        <div className="goal-block">
          <p className="eyebrow">Sleep goal (hours)</p>
          <div className="chip-row" role="radiogroup" aria-label="Sleep goal">
            {sleepOptions.map((g) => (
              <button
                key={g}
                type="button"
                className={`chip${settings.sleepGoal === g ? " chip--active" : ""}`}
                onClick={() => updateSleep(g)}
              >
                {g}
              </button>
            ))}
          </div>
          <p className="muted small-copy">Default is 7.5 hours.</p>
        </div>

        <div className="goal-block">
          <p className="eyebrow">Fiber goal (grams)</p>
          <div className="chip-row" role="radiogroup" aria-label="Fiber goal">
            {fiberOptions.map((g) => (
              <button
                key={g}
                type="button"
                className={`chip${settings.fiberGoal === g ? " chip--active" : ""}`}
                onClick={() => updateFiber(g)}
              >
                {g}
              </button>
            ))}
          </div>
          <p className="muted small-copy">Default is 40 grams.</p>
        </div>

        <div className="goal-block">
          <p className="eyebrow">Exercise goal</p>
          <p className="lede">Fixed at 30 minutes (Apple Health Exercise Minutes).</p>
        </div>
      </section>

      <section className="card stack-gap">
        <h2 className="section-title">Import into this app</h2>
        <p className="muted small-copy">
          Shortcuts usually open a URL in Safari (or another browser), which can be a{" "}
          <strong>different storage bucket</strong> than the icon installed from “Add to Home
          Screen.” Pasting the full import URL here runs import <strong>inside this window</strong>{" "}
          so data saves where you are using the app.
        </p>
        <form className="stack-form" onSubmit={handlePastedImport}>
          <label className="field">
            <span>Paste full import URL</span>
            <textarea
              rows={3}
              className="field-textarea"
              value={pastedImportUrl}
              onChange={(ev) => setPastedImportUrl(ev.target.value)}
              placeholder={sampleUrl}
              autoComplete="off"
              spellCheck={false}
            />
          </label>
          <button type="submit" className="btn-primary">
            Run import
          </button>
        </form>
      </section>

      <section className="card stack-gap">
        <h2 className="section-title">Data management</h2>
        <p className="muted">
          Records stay in this browser unless you export them. Clearing site data will remove them.
        </p>
        <div className="button-row">
          <button type="button" className="btn-secondary" onClick={handleExport}>
            Export records as JSON
          </button>
          <button type="button" className="btn-danger" onClick={handleClear}>
            Clear all local data
          </button>
        </div>
      </section>

      <section className="card stack-gap prose-card">
        <h2 className="section-title">Apple Shortcut URL</h2>
        <p className="muted">
          Shortcut format (same domain as this app):
        </p>
        <pre className="code-block wrap">{templateUrl}</pre>
        <p className="muted">Example:</p>
        <pre className="code-block wrap">{sampleUrl}</pre>
        <p className="muted small-copy">
          Zeros trigger correction. For the Home Screen app, use{" "}
          <strong>Import into this app</strong> above if Safari does not share data with your
          installed icon.
        </p>
      </section>

      <section className="card stack-gap prose-card">
        <h2 className="section-title">8:00 PM automation (iOS)</h2>
        <ol className="numbered-list">
          <li>Open the Shortcuts app → Automation.</li>
          <li>Create Personal Automation → Time of Day → 8:00 PM → Daily.</li>
          <li>Action: Run Shortcut → choose your Daily Health Score shortcut.</li>
          <li>Turn off Ask Before Running / use Run Immediately where available.</li>
        </ol>
      </section>
    </div>
  );
}
