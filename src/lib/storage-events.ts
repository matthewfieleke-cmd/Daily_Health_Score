/** Bump UI when records/settings synced from local writes or cloud pull. */
export const DHS_STORAGE_UPDATED = "dhs-storage-updated";

export function notifyRecordsUpdated(): void {
  window.dispatchEvent(new CustomEvent(DHS_STORAGE_UPDATED));
}
