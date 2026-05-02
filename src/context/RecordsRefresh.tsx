import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { pullCloudIntoLocal } from "../lib/cloud-sync";
import { RecordsVersionContext } from "./records-version-context";
import { DHS_STORAGE_UPDATED } from "../lib/storage-events";

export function RecordsRefreshProvider({ children }: { children: ReactNode }) {
  const [version, setVersion] = useState(0);
  const [isSyncing, setIsSyncing] = useState(false);
  const bump = useCallback(() => setVersion((v) => v + 1), []);

  const pull = useCallback(async () => {
    setIsSyncing(true);
    try {
      const ok = await pullCloudIntoLocal();
      if (ok) bump();
    } finally {
      setIsSyncing(false);
    }
  }, [bump]);

  useEffect(() => {
    window.addEventListener(DHS_STORAGE_UPDATED, bump);
    return () => window.removeEventListener(DHS_STORAGE_UPDATED, bump);
  }, [bump]);

  useEffect(() => {
    function onVisibility() {
      if (document.visibilityState !== "visible") return;
      void pull();
    }
    document.addEventListener("visibilitychange", onVisibility);
    const initialPull = window.setTimeout(() => {
      void pull();
    }, 0);
    return () => {
      window.clearTimeout(initialPull);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, [pull]);

  const value = useMemo(() => ({ version, isSyncing }), [version, isSyncing]);

  return (
    <RecordsVersionContext.Provider value={value}>
      {children}
    </RecordsVersionContext.Provider>
  );
}
