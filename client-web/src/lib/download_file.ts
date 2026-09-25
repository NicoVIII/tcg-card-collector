// A thin wrapper around the browser download APIs (Blob, object URLs, an
// off-DOM anchor) — nothing here is business logic worth unit-testing, same
// posture as data/http/skir_rpc.ts's window.location touch.
export function downloadFile(filename: string, content: string, mimeType: string): void {
  const url = URL.createObjectURL(new Blob([content], { type: mimeType }));
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}
