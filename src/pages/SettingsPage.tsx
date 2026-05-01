import type { FormEvent } from "react";
import { useReducer, useState } from "react";
import { useNavigate } from "react-router-dom";
import type { FiberGoalGrams, SleepGoalHours } from "../types/health";
import { pullCloudIntoLocal, pushRemoteSettings } from "../lib/cloud-sync";
import { localDateKey } from "../lib/dates";
import { parseImportUrlToSearch } from "../lib/import-url";
import {
  clearAllLocalData,
  exportRecordsAsJson,
  getSyncToken,
  loadSettings,
  saveSettings,
  setSyncToken,
} from "../lib/storage";

const sleepOptions: SleepGoalHours[] = [7, 7.5, 8];
const fiberOptions: FiberGoalGrams[] = [30, 40, 50];

export function SettingsPage() {
  const navigate = useNavigate();
  const [settings, setSettings] = useState(loadSettings);
  const [pastedImportUrl, setPastedImportUrl] = useState("");
  const [, bumpTokenUi] = useReducer((n: number) => n + 1, 0);

  const baseUrl =
    typeof window !== "undefined"
      ? window.location.origin
      : "https://YOUR-VERCEL-APP.vercel.app";

  const syncToken = getSyncToken();

  function generateSyncToken() {
    const id = crypto.randomUUID();
    setSyncToken(id);
    bumpTokenUi();
  }

  function removeSyncToken() {
    setSyncToken(null);
    bumpTokenUi();
  }

  async function handlePullCloud() {
    const ok = await pullCloudIntoLocal();
    if (ok) {
      setSettings(loadSettings());
    } else {
      window.alert(
        "Could not pull from cloud. Check that Vercel KV is configured and your token matches.",
      );
    }
  }

  async function copySyncToken() {
    const t = getSyncToken();
    if (!t) return;
    try {
      await navigator.clipboard.writeText(t);
      window.alert("Token copied.");
    } catch {
      window.alert("Could not copy automatically—select and copy the token manually.");
    }
  }

  function updateSleep(goal: SleepGoalHours) {
    const next = { ...settings, sleepGoal: goal };
    setSettings(next);
    saveSettings(next);
    void pushRemoteSettings(next);
  }

  function updateFiber(goal: FiberGoalGrams) {
    const next = { ...settings, fiberGoal: goal };
    setSettings(next);
    saveSettings(next);
    void pushRemoteSettings(next);
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
    bumpTokenUi();
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
  const ingestUrl = `${baseUrl}/api/ingest`;
  const sampleJson =
    '{"date":"2026-05-01","sleep":7.4,"fiber":38,"exercise":28}';

  return (
    <div className="page-content">
      <h1 className="page-title">Settings</h1>

      <section className="card stack-gap prose-card">
        <h2 className="section-title">Cloud backup (Shortcut POST)</h2>
        <p className="muted small-copy">
          Connect Vercel KV on your deployment. Your Shortcut can POST daily metrics to the API so
          the Home Screen app picks them up on next open (pull runs automatically when you return
          to the tab).
        </p>
        <div className="button-row">
          <button type="button" className="btn-primary" onClick={generateSyncToken}>
            Generate sync token
          </button>
          {syncToken ? (
            <>
              <button type="button" className="btn-secondary" onClick={copySyncToken}>
                Copy token
              </button>
              <button type="button" className="btn-secondary" onClick={handlePullCloud}>
                Pull from cloud now
              </button>
              <button type="button" className="btn-danger" onClick={removeSyncToken}>
                Remove token on this device
              </button>
            </>
          ) : null}
        </div>
        {syncToken ? (
          <>
            <p className="muted small-copy">
              Add header <code className="inline-code">Authorization: Bearer [token]</code> (same
              token everywhere—keep it secret).
            </p>
            <pre className="code-block wrap">{syncToken}</pre>
            <p className="muted small-copy">POST URL:</p>
            <pre className="code-block wrap">{ingestUrl}</pre>
            <p className="muted small-copy">JSON body example:</p>
            <pre className="code-block wrap">{sampleJson}</pre>
          </>
        ) : (
          <p className="muted small-copy">Generate a token before configuring your Shortcut.</p>
        )}
      </section>

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
        <h2 className="section-title">Apple Shortcut</h2>
        <p className="muted">
          <strong>Recommended (cloud):</strong> POST JSON to{" "}
          <code className="inline-code">{ingestUrl}</code> with Bearer token and body matching the
          example above (zeros not allowed—fix zero readings before POST).
        </p>
        <p className="muted">
          <strong>Alternative (browser URL):</strong>
        </p>
        <pre className="code-block wrap">{templateUrl}</pre>
        <p className="muted">Example:</p>
        <pre className="code-block wrap">{sampleUrl}</pre>
        <p className="muted small-copy">
          Zeros trigger correction in the app. With a sync token, prefer POST so data lands in KV for
          your Home Screen build.
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
