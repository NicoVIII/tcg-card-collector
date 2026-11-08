import { For, Show, createSignal } from "solid-js";
import { useCardQuery } from "../data/card_catalog/query";
import { useFetchOwnedCopies } from "../data/collection/query";
import { useFetchManagedLocations } from "../data/managed_location/query";
import { useRemoveCardsMutation } from "../data/collection_remove/mutation";
import { mapError } from "../data/http/error";
import { ConfirmButton } from "../components/confirm_button";
import { CopyEntryForm, type RawCopyEntry } from "../components/copy_entry_form";
import {
  type StagedEntry,
  exceedsOwned,
  normalizeEntry,
  printingKey,
  refreshOwned,
  removeEntry,
  stageEntry,
  staleMessage,
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
      <span class="staging-key" classList={{ "staging-over": exceedsOwned(props.entry) }}>
        {props.entry.quantity}x {props.entry.setCode} {props.entry.collectorNumber} (
        {props.entry.finish}·{props.entry.language}) of {props.entry.owned} owned
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
  const [staged, setStaged] = createSignal<StagedEntry[]>([]);
  const [formError, setFormError] = createSignal<string | null>(null);
  const [submitError, setSubmitError] = createSignal<string | null>(null);
  const [successNote, setSuccessNote] = createSignal<string | null>(null);
  const mutation = useRemoveCardsMutation();
  const fetchOwnedCopies = useFetchOwnedCopies();
  const fetchManagedLocations = useFetchManagedLocations();
  const stageFromForm = async (raw: RawCopyEntry): Promise<boolean> => {
    const entry = normalizeEntry(raw);
    if (entry === null) {
      setFormError("Enter a set code, a collector number, and a quantity of at least 1.");
      return false;
    }
    setSuccessNote(null);
    let result;
    try {
      const [owned, decks] = await Promise.all([
        fetchOwnedCopies(entry.setCode, entry.collectorNumber),
        fetchManagedLocations(),
      ]);
      // Read after the await: another staging may have landed meanwhile.
      result = stageEntry(staged(), entry, owned, decks);
    } catch (error) {
      setFormError(mapError(error).message);
      return false;
    }
    if (!result.ok) {
      setFormError(result.message);
      return false;
    }
    setFormError(null);
    setStaged(result.list);
    return true;
  };

  const fetchCopiesByPrinting = async (list: StagedEntry[]) => {
    const printings = [...new Map(list.map((entry) => [printingKey(entry), entry])).values()];
    const copies = await Promise.all(
      printings.map((entry) => fetchOwnedCopies(entry.setCode, entry.collectorNumber)),
    );
    return new Map(printings.map((entry, index) => [printingKey(entry), copies[index]]));
  };

  // A 400 here means the collection moved since staging (ADR 0021): re-read
  // what's owned so the offending rows are marked, rather than echoing the
  // server's message.
  const handleStaleRejection = async () => {
    try {
      const copiesByPrinting = await fetchCopiesByPrinting(staged());
      const refreshed = refreshOwned(staged(), copiesByPrinting);
      setStaged(refreshed);
      setSubmitError(staleMessage(refreshed));
    } catch (error) {
      setSubmitError(mapError(error).message);
    }
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
      const appError = mapError(error);
      if (appError.status === 400) {
        await handleStaleRejection();
        return;
      }
      setSubmitError(appError.message);
    }
  };

  return (
    <div class="remove-cards-panel">
      <h3>Remove cards</h3>
      <CopyEntryForm submitLabel="Add to list" onSubmit={stageFromForm} />
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
          disabled={mutation.isPending || staged().some(exceedsOwned)}
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
