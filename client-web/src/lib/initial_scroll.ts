// A page-load-only, one-shot scroll to the open accordion location (#142).
// Toggling a location open/closed already scrolls its header via the
// `onClick` handlers in placement_page.tsx / inventory_page.tsx — this only
// covers the case those don't: landing on the page (reload, Back/Forward, a
// fresh `?location=` link) with a location already open. Native
// `scrollRestoration` can't be trusted for that because the page is often
// still short when it fires, so the restored offset gets clamped away.
export type InitialScroll = {
  /** Scrolls `headerEl` into view the first time it's called; every later
   *  call is a no-op. Call this from the open location's panel ref — its
   *  data has arrived by then, but the panel's own `ref` still fires mid-
   *  render, while the rest of the location list (and anything above it)
   *  is still being inserted into the document. Measuring layout that
   *  early catches a still-growing page, so the scroll is pushed one frame
   *  out to land after the browser has committed the full layout. */
  panelShown: (headerEl: HTMLElement) => void;
  /** Disarms without scrolling — a user toggle takes over from here. */
  cancel: () => void;
};

export function createInitialScroll(): InitialScroll {
  let pending = true;

  const panelShown = (headerEl: HTMLElement) => {
    if (!pending) {
      return;
    }
    pending = false;
    requestAnimationFrame(() => headerEl.scrollIntoView({ block: "start" }));
  };

  const cancel = () => {
    pending = false;
  };

  return { panelShown, cancel };
}
