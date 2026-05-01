import { NavLink, Outlet } from "react-router-dom";

const nav = [
  { to: "/today", label: "Today" },
  { to: "/week", label: "7-Day" },
  { to: "/month", label: "30-Day" },
  { to: "/settings", label: "Settings" },
];

export function Layout() {
  return (
    <div className="shell">
      <header className="top-bar">
        <div className="brand">
          <span className="brand__title">Daily Health Score</span>
          <span className="brand__subtitle">Local dashboard</span>
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
        <Outlet />
      </main>
    </div>
  );
}
