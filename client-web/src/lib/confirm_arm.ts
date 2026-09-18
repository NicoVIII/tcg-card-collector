import { createSignal, onCleanup } from "solid-js";

// Arming state for a two-step "Confirm?" button: the first activate() only
// arms it, the second runs the action and disarms. A timeout is the safety
// net for touch — on iOS a tapped button often never receives focus, so a
// blur-based disarm never fires and the button would otherwise stay armed
// indefinitely for a stray later tap.
const DISARM_AFTER_MS = 5000;

export function createConfirmArm(onConfirm: () => void, timeoutMs = DISARM_AFTER_MS) {
  const [armed, setArmed] = createSignal(false);
  let timer: ReturnType<typeof setTimeout> | undefined;

  const clearTimer = () => {
    clearTimeout(timer);
    timer = undefined;
  };

  const disarm = () => {
    clearTimer();
    setArmed(false);
  };

  const activate = () => {
    if (armed()) {
      disarm();
      onConfirm();
      return;
    }
    setArmed(true);
    clearTimer();
    timer = setTimeout(disarm, timeoutMs);
  };

  onCleanup(clearTimer);

  return { armed, activate, disarm };
}
