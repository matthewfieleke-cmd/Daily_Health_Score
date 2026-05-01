import { createContext, useContext } from "react";

export const RecordsVersionContext = createContext(0);

export function useRecordsVersion(): number {
  return useContext(RecordsVersionContext);
}
