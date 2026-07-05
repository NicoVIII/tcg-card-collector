import { For, Show, createSignal } from "solid-js";
import { A } from "@solidjs/router";
import { useCardQuery } from "../data/card_catalog/query";
import { useAddCardsMutation } from "../data/collection_add/mutation";
import { mapError } from "../data/http/error";
import {
  type StagedEntry,
  addEntry,
  normalizeEntry,
  removeEntry,
  toAddCardsRows,
  totalCards,
} from "./add_cards_staging";

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
        {props.entry.quantity}x {props.entry.setCode} {props.entry.collectorNumber}
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

// The "open a booster" flow: the set code sticks between entries, the
// collector number field is cleared and refocused after each one, and the
// staged list is committed as a single AddCards batch.
export function AddCardsPanel() {
  const [setCode, setSetCode] = createSignal("");
  const [collectorNumber, setCollectorNumber] = createSignal("");
  const [quantity, setQuantity] = createSignal("1");
  const [staged, setStaged] = createSignal<StagedEntry[]>([]);
  const [formError, setFormError] = createSignal<string | null>(null);
  const [submitError, setSubmitError] = createSignal<string | null>(null);
  const [successNote, setSuccessNote] = createSignal<string | null>(null);
  const [placedCount, setPlacedCount] = createSignal(0);
  const mutation = useAddCardsMutation();
  let collectorNumberInput: HTMLInputElement | undefined;

  const stageEntry = (event: Event) => {
    event.preventDefault();
    const entry = normalizeEntry({
      setCode: setCode(),
      collectorNumber: collectorNumber(),
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
        rows: toAddCardsRows(staged()),
      });
      if (!response.added) {
        setSubmitError("The server rejected the staged cards.");
        return;
      }
      setStaged([]);
      setSuccessNote(`Added ${count} card(s) to the collection.`);
      setPlacedCount(count);
    } catch (error) {
      setSubmitError(mapError(error).message);
    }
  };

  return (
    <div class="add-cards-panel">
      <h3>Add cards</h3>
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
        <button type="button" onClick={() => void commit()} disabled={mutation.isPending}>
          Add {totalCards(staged())} card(s) to collection
        </button>
      </Show>
      <Show when={submitError() !== null}>
        <p role="alert">{submitError()}</p>
      </Show>
      <Show when={successNote() !== null}>
        <p class="success">
          {successNote()} <A href="/placement">{placedCount()} card(s) to place</A>
        </p>
      </Show>
    </div>
  );
}
