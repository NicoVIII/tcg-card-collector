import { For, Show, createSignal } from "solid-js";
import { useCardQuery } from "../data/card_catalog/query";
import { useRemoveCardsMutation } from "../data/collection_remove/mutation";
import {
  DEFAULT_FINISH,
  DEFAULT_LANGUAGE,
  FINISHES,
  LANGUAGES,
  type Finish,
  type Language,
} from "../data/collection/copy_kind";
import { mapError } from "../data/http/error";
import { ConfirmButton } from "../components/confirm_button";
import {
  type StagedEntry,
  addEntry,
  normalizeEntry,
  removeEntry,
  toRemoveCardsRows,
  totalCards,
} from "./remove_cards_staging";

function StagedRow(props: { entry: StagedEntry; onRemove: () => void }) {
  const cardQuery = useCardQuery(() => ({
    set_code: props.entry.setCode,
    collector_number: props.entry.collectorNumber,
  }));

  const cardName = () => {
    if (cardQuery.isLoading) {
      return "Looking up…";
    }
    return cardQuery.data?.name ?? "Unknown card (not in catalog)";
  };

  return (
    <li class="staging-row">
      <Show when={cardQuery.data?.image_uri} fallback={<span class="staging-thumb" />}>
        <img class="staging-thumb" src={cardQuery.data?.image_uri} alt="" />
      </Show>
      <span class="staging-key">
        {props.entry.quantity}x {props.entry.setCode} {props.entry.collectorNumber} (
        {props.entry.finish}·{props.entry.language})
      </span>
      <span class="staging-name" classList={{ "staging-name-unknown": cardQuery.data === null }}>
        {cardName()}
      </span>
      <button
        type="button"
        class="staging-remove"
        aria-label={`Remove ${props.entry.setCode} ${props.entry.collectorNumber}`}
        onClick={() => props.onRemove()}
      >
        ✕
      </button>
    </li>
  );
}

// Same stage-then-commit shape as AddCardsPanel, but the commit is a
// destructive collection edit (app-first: the app's recorded quantity is
// what's being corrected, not a physical event already in hand), so it goes
// through the shared two-step ConfirmButton instead of firing on one click.
export function RemoveCardsPanel() {
  const [setCode, setSetCode] = createSignal("");
  const [collectorNumber, setCollectorNumber] = createSignal("");
  const [finish, setFinish] = createSignal<Finish>(DEFAULT_FINISH);
  const [language, setLanguage] = createSignal<Language>(DEFAULT_LANGUAGE);
  const [quantity, setQuantity] = createSignal("1");
  const [staged, setStaged] = createSignal<StagedEntry[]>([]);
  const [formError, setFormError] = createSignal<string | null>(null);
  const [submitError, setSubmitError] = createSignal<string | null>(null);
  const [successNote, setSuccessNote] = createSignal<string | null>(null);
  const mutation = useRemoveCardsMutation();
  let collectorNumberInput: HTMLInputElement | undefined;

  const stageEntry = (event: Event) => {
    event.preventDefault();
    const entry = normalizeEntry({
      setCode: setCode(),
      collectorNumber: collectorNumber(),
      finish: finish(),
      language: language(),
      quantity: Number.parseInt(quantity(), 10),
    });
    if (entry === null) {
      setFormError("Enter a set code, a collector number, and a quantity of at least 1.");
      return;
    }
    setFormError(null);
    setSuccessNote(null);
    setStaged((list) => addEntry(list, entry));
    setCollectorNumber("");
    setQuantity("1");
    collectorNumberInput?.focus();
  };

  const commit = async () => {
    setSubmitError(null);
    setSuccessNote(null);
    const count = totalCards(staged());
    try {
      const response = await mutation.mutateAsync({
        rows: toRemoveCardsRows(staged()),
      });
      if (!response.decremented) {
        setSubmitError("The server rejected the staged cards.");
        return;
      }
      setStaged([]);
      setSuccessNote(`Removed ${count} card(s) from the collection.`);
    } catch (error) {
      setSubmitError(mapError(error).message);
    }
  };

  return (
    <div class="remove-cards-panel">
      <h3>Remove cards</h3>
      <form class="form-row" onSubmit={stageEntry}>
        <label>
          Set
          <input
            value={setCode()}
            onInput={(event) => setSetCode(event.currentTarget.value)}
            placeholder="blb"
            size={6}
          />
        </label>
        <label>
          Number
          <input
            ref={(element) => {
              collectorNumberInput = element;
            }}
            value={collectorNumber()}
            onInput={(event) => setCollectorNumber(event.currentTarget.value)}
            placeholder="123"
            size={6}
          />
        </label>
        <label>
          Finish
          <select
            value={finish()}
            onChange={(event) => setFinish(event.currentTarget.value as Finish)}
          >
            <For each={FINISHES}>{(option) => <option value={option}>{option}</option>}</For>
          </select>
        </label>
        <label>
          Language
          <select
            value={language()}
            onChange={(event) => setLanguage(event.currentTarget.value as Language)}
          >
            <For each={LANGUAGES}>{(option) => <option value={option}>{option}</option>}</For>
          </select>
        </label>
        <label>
          Quantity
          <input
            type="number"
            min="1"
            value={quantity()}
            onInput={(event) => setQuantity(event.currentTarget.value)}
          />
        </label>
        <button type="submit">Add to list</button>
      </form>
      <Show when={formError() !== null}>
        <p role="alert">{formError()}</p>
      </Show>
      <Show when={staged().length > 0}>
        <ul class="staging-list">
          <For each={staged()}>
            {(entry) => (
              <StagedRow
                entry={entry}
                onRemove={() => setStaged((list) => removeEntry(list, entry))}
              />
            )}
          </For>
        </ul>
        <ConfirmButton
          label={`Remove ${totalCards(staged())} card(s) from collection`}
          disabled={mutation.isPending}
          onConfirm={() => void commit()}
        />
      </Show>
      <Show when={submitError() !== null}>
        <p role="alert">{submitError()}</p>
      </Show>
      <Show when={successNote() !== null}>
        <p class="success">{successNote()}</p>
      </Show>
    </div>
  );
}
