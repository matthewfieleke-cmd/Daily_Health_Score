/** True for `/import` with optional trailing slash. */
function isImportPath(pathname: string): boolean {
  const normalized = pathname.replace(/\/+$/, "") || "/";
  return normalized === "/import";
}

/**
 * Extracts the query string (including leading `?`) from a pasted import URL so it can be routed to `/import`.
 * Accepts absolute URLs or site-relative paths like `/import?date=...`.
 */
export function parseImportUrlToSearch(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;

  try {
    const u = new URL(trimmed);
    if (!isImportPath(u.pathname)) return null;
    if (!u.search || u.search === "?") return null;
    return u.search;
  } catch {
    if (trimmed.startsWith("/import?")) {
      return trimmed.slice("/import".length);
    }
    if (trimmed.startsWith("import?")) {
      return `?${trimmed.slice("import?".length)}`;
    }
    return null;
  }
}
