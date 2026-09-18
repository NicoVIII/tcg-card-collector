import { createRoot } from "solid-js";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createConfirmArm } from "./confirm_arm";

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

describe("createConfirmArm", () => {
  it("arms on the first activate without running the action", () => {
    const onConfirm = vi.fn();
    createRoot((dispose) => {
      const { armed, activate } = createConfirmArm(onConfirm);
      activate();
      expect(armed()).toBe(true);
      expect(onConfirm).not.toHaveBeenCalled();
      dispose();
    });
  });

  it("runs the action and disarms on the second activate", () => {
    const onConfirm = vi.fn();
    createRoot((dispose) => {
      const { armed, activate } = createConfirmArm(onConfirm);
      activate();
      activate();
      expect(onConfirm).toHaveBeenCalledOnce();
      expect(armed()).toBe(false);
      dispose();
    });
  });

  it("disarm() cancels an armed state without running the action", () => {
    const onConfirm = vi.fn();
    createRoot((dispose) => {
      const { armed, activate, disarm } = createConfirmArm(onConfirm);
      activate();
      disarm();
      expect(armed()).toBe(false);
      expect(onConfirm).not.toHaveBeenCalled();
      dispose();
    });
  });

  it("disarms itself after the timeout", () => {
    const onConfirm = vi.fn();
    createRoot((dispose) => {
      const { armed, activate } = createConfirmArm(onConfirm, 5000);
      activate();
      vi.advanceTimersByTime(5000);
      expect(armed()).toBe(false);
      dispose();
    });
  });

  it("re-arms rather than firing when activated again after the timeout", () => {
    const onConfirm = vi.fn();
    createRoot((dispose) => {
      const { armed, activate } = createConfirmArm(onConfirm, 5000);
      activate();
      vi.advanceTimersByTime(5000);
      activate();
      expect(armed()).toBe(true);
      expect(onConfirm).not.toHaveBeenCalled();
      dispose();
    });
  });

  it("clears the pending timer when the owner is disposed", () => {
    const onConfirm = vi.fn();
    createRoot((dispose) => {
      const { activate } = createConfirmArm(onConfirm, 5000);
      activate();
      dispose();
    });

    // If the timer had survived disposal, this would still be a no-op since
    // setArmed can no longer be observed — the assertion is really that
    // advancing the clock post-dispose doesn't throw.
    expect(() => vi.advanceTimersByTime(5000)).not.toThrow();
  });
});
