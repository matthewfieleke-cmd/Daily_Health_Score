import { NavLink, Outlet } from "react-router-dom";
import { RecordsRefreshProvider } from "../context/RecordsRefresh";
import { useRecordsSyncStatus } from "../context/records-version-context";

const nav = [
  { to: "/today", label: "Today" },
  { to: "/week", label: "7-Day" },
  { to: "/month", label: "30-Day" },
  { to: "/ninety", label: "90-Day" },
  { to: "/settings", label: "Settings" },
];

function SyncStatusBanner() {
  const isSyncing = useRecordsSyncStatus();
  if (!isSyncing) return null;
  return <p className="callout callout--compact">Syncing health data...</p>;
}

export function Layout() {
  return (
    <div className="shell">
      <header className="top-bar">
        <div className="brand">
          <img
            src="/DHS.png"
            alt=""
            width={36}
            height={36}
            className="brand-icon"
          />
          <span className="brand__title">Daily Health Score</span>
        </div>
        <nav className="tab-nav" aria-label="Primary">
          {nav.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `tab-link${isActive ? " tab-link--active" : ""}`
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
      </header>
      <main className="main-region">
        <RecordsRefreshProvider>
          <SyncStatusBanner />
          <Outlet />
        </RecordsRefreshProvider>
      </main>
    </div>
  );
}
