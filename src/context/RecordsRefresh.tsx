import {
  useCallback,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import { pullCloudIntoLocal } from "../lib/cloud-sync";
import { RecordsVersionContext } from "./records-version-context";
import { DHS_STORAGE_UPDATED } from "../lib/storage-events";

export function RecordsRefreshProvider({ children }: { children: ReactNode }) {
  const [version, setVersion] = useState(0);
  const bump = useCallback(() => setVersion((v) => v + 1), []);

  useEffect(() => {
    window.addEventListener(DHS_STORAGE_UPDATED, bump);
    return () => window.removeEventListener(DHS_STORAGE_UPDATED, bump);
  }, [bump]);

  useEffect(() => {
    function onVisibility() {
      if (document.visibilityState !== "visible") return;
      void pullCloudIntoLocal().then((ok) => {
        if (ok) bump();
      });
    }
    document.addEventListener("visibilitychange", onVisibility);
    void pullCloudIntoLocal().then((ok) => {
      if (ok) bump();
    });
    return () =>
      document.removeEventListener("visibilitychange", onVisibility);
  }, [bump]);

  return (
    <RecordsVersionContext.Provider value={version}>
      {children}
    </RecordsVersionContext.Provider>
  );
}
