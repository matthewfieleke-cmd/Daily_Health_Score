import type { FormEvent } from "react";
import { useReducer, useState } from "react";
import { useNavigate } from "react-router-dom";
import type { FiberGoalGrams, SleepGoalHours } from "../types/health";
import { applyImportPayload, pullCloudIntoLocal, pushRemoteSettings } from "../lib/cloud-sync";
import { isValidDateKey, localDateKey } from "../lib/dates";
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
  const [fixDate, setFixDate] = useState(() => localDateKey());
  const [fixSleep, setFixSleep] = useState("");
  const [fixFiber, setFixFiber] = useState("");
  const [fixExercise, setFixExercise] = useState("");
  const [fixError, setFixError] = useState<string | null>(null);
  const [fixBusy, setFixBusy] = useState(false);
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
        "Paste a full URL that ends in /import and includes the date plus sleep (or sleepHours), fiber, and exercise.",
      );
      return;
    }
    setPastedImportUrl("");
    navigate(`/import${search}`);
  }

  async function handleFixSavedDay(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setFixError(null);
    const date = fixDate.trim();
    if (!isValidDateKey(date)) {
      setFixError("Use a calendar date like 2026-05-18.");
      return;
    }
    const sleep = Number(fixSleep);
    const fiber = Number(fixFiber);
    const exercise = Number(fixExercise);
    if (!Number.isFinite(sleep) || sleep < 0) {
      setFixError("Sleep (hours) must be a number zero or greater.");
      return;
    }
    if (!Number.isFinite(fiber) || fiber < 0) {
      setFixError("Fiber (grams) must be a number zero or greater.");
      return;
    }
    if (!Number.isFinite(exercise) || exercise < 0) {
      setFixError("Exercise (minutes) must be a number zero or greater.");
      return;
    }
    setFixBusy(true);
    try {
      await applyImportPayload({ date, sleep, fiber, exercise });
      navigate("/today", {
        state: {
          importSaved: { date, sleep, fiber, exercise },
        },
      });
    } finally {
      setFixBusy(false);
    }
  }

  const sampleUrl = `${baseUrl}/import?date=2026-05-01&sleep=7.4&fiber=38&exercise=28`;
  const templateUrl = `${baseUrl}/import?date=yyyy-MM-dd&sleep=[sleep]&fiber=[fiber]&exercise=[exercise]`;
  const ingestUrl = `${baseUrl}/api/ingest`;
  const sampleJson =
    '{"syncToken":"[token]","date":"yyyy-MM-dd","sleepHours":7.4,"fiberGrams":38,"exerciseMinutes":28}';

  return (
    <div className="page-content">
      <h1 className="page-title">Settings</h1>

      <section className="card stack-gap prose-card">
        <h2 className="section-title">Cloud backup (Shortcut POST)</h2>
        <p className="muted small-copy">
          Connect Vercel KV on your deployment. Your Shortcut can POST daily metrics to the API so
          the Home Screen app picks them up on next open. Launch from your Home Screen Shortcut icon
          to refresh Health data before the PWA opens.
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
              For Shortcuts, include <code className="inline-code">syncToken</code> in the JSON body
              instead of using an Authorization header (same token everywhere—keep it secret).
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
        <h2 className="section-title">Adjust a saved day</h2>
        <p className="muted small-copy">
          Use this when a day saved with the wrong numbers—especially sleep that does not match
          Apple Health. It overwrites that date the same way a fresh import would. If you use cloud
          sync, the update is sent to the server too.
        </p>
        <form className="stack-form" onSubmit={handleFixSavedDay}>
          <label className="field">
            <span>Date (yyyy-MM-dd)</span>
            <input
              type="text"
              value={fixDate}
              onChange={(ev) => setFixDate(ev.target.value)}
              autoComplete="off"
              spellCheck={false}
            />
          </label>
          <label className="field">
            <span>Sleep (hours)</span>
            <input
              type="number"
              step="0.1"
              min={0}
              required
              value={fixSleep}
              onChange={(ev) => setFixSleep(ev.target.value)}
            />
          </label>
          <label className="field">
            <span>Fiber (grams)</span>
            <input
              type="number"
              step="0.1"
              min={0}
              required
              value={fixFiber}
              onChange={(ev) => setFixFiber(ev.target.value)}
            />
          </label>
          <label className="field">
            <span>Exercise (minutes)</span>
            <input
              type="number"
              step="1"
              min={0}
              required
              value={fixExercise}
              onChange={(ev) => setFixExercise(ev.target.value)}
            />
          </label>
          {fixError ? <p className="error-text">{fixError}</p> : null}
          <button type="submit" className="btn-primary" disabled={fixBusy}>
            {fixBusy ? "Saving…" : "Save this day"}
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
          <strong>Recommended launcher:</strong> Add one Shortcut to your Home Screen. It should
          collect AutoSleep Time Asleep plus today’s Apple Health fiber and exercise, POST one record
          to <code className="inline-code">{ingestUrl}</code>, then open this PWA. Running it again
          the same day overwrites today’s record. Zeros are allowed and score as zero.
        </p>
        <p className="muted">
          <strong>Alternative (browser URL):</strong>
        </p>
        <pre className="code-block wrap">{templateUrl}</pre>
        <p className="muted">Example:</p>
        <pre className="code-block wrap">{sampleUrl}</pre>
        <p className="muted small-copy">
          URL imports still trigger correction for zeros. With a sync token, prefer POST so data
          lands in KV for your Home Screen build.
        </p>
      </section>
    </div>
  );
}
