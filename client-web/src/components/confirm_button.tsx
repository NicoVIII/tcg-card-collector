import { createConfirmArm } from "../lib/confirm_arm";

type Props = {
  label: string;
  ariaLabel?: string;
  disabled?: boolean;
  onConfirm: () => void;
};

// A destructive action's button: the first click arms it to "Confirm?", the
// second runs onConfirm. Blur or Escape disarms early; a timeout (inside
// createConfirmArm) disarms it regardless, since a tapped button on touch
// devices often never receives focus to blur from.
export function ConfirmButton(props: Props) {
  const { armed, activate, disarm } = createConfirmArm(() => props.onConfirm());

  return (
    <button
      type="button"
      classList={{ "confirm-armed": armed() }}
      disabled={props.disabled}
      aria-label={armed() ? `Confirm: ${props.ariaLabel ?? props.label}` : props.ariaLabel}
      aria-live="polite"
      onClick={activate}
      onBlur={disarm}
      onKeyDown={(event) => {
        if (event.key === "Escape") disarm();
      }}
    >
      {armed() ? "Confirm?" : props.label}
    </button>
  );
}
