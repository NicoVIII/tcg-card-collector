import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createInitialScroll } from "./initial_scroll";

function fakeHeader() {
  return { scrollIntoView: vi.fn() } as unknown as HTMLElement;
}

// The node test environment has no requestAnimationFrame at all (unlike a
// browser's fake-timers backend, there's nothing there for vitest to fake) —
// stub it directly, queuing callbacks to run on `flush()`.
function stubAnimationFrame() {
  const callbacks: FrameRequestCallback[] = [];
  vi.stubGlobal("requestAnimationFrame", (callback: FrameRequestCallback) => {
    callbacks.push(callback);
    return callbacks.length;
  });
  return { flush: () => callbacks.splice(0).forEach((callback) => callback(0)) };
}

beforeEach(() => {
  vi.unstubAllGlobals();
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("createInitialScroll", () => {
  it("scrolls the header into view, one frame after the first call", () => {
    const { flush } = stubAnimationFrame();
    const initialScroll = createInitialScroll();
    const header = fakeHeader();

    initialScroll.panelShown(header);
    expect(header.scrollIntoView).not.toHaveBeenCalled();

    flush();
    expect(header.scrollIntoView).toHaveBeenCalledExactlyOnceWith({ block: "start" });
  });

  it("does nothing on a later call", () => {
    const { flush } = stubAnimationFrame();
    const initialScroll = createInitialScroll();
    const first = fakeHeader();
    const second = fakeHeader();

    initialScroll.panelShown(first);
    initialScroll.panelShown(second);
    flush();

    expect(second.scrollIntoView).not.toHaveBeenCalled();
  });

  it("cancel() before the first call prevents the scroll", () => {
    const { flush } = stubAnimationFrame();
    const initialScroll = createInitialScroll();
    const header = fakeHeader();

    initialScroll.cancel();
    initialScroll.panelShown(header);
    flush();

    expect(header.scrollIntoView).not.toHaveBeenCalled();
  });
});
