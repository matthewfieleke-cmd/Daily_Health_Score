import { createContext, useContext } from "react";

type RecordsRefreshContextValue = {
  version: number;
  isSyncing: boolean;
};

export const RecordsVersionContext = createContext<RecordsRefreshContextValue>({
  version: 0,
  isSyncing: false,
});

export function useRecordsVersion(): number {
  return useContext(RecordsVersionContext).version;
}

export function useRecordsSyncStatus(): boolean {
  return useContext(RecordsVersionContext).isSyncing;
}
