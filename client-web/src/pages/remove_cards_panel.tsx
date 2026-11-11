import { For, Show, createSignal } from "solid-js";
import { useCardQuery } from "../data/card_catalog/query";
import { useFetchOwnedCopies } from "../data/collection/query";
import { useFetchManagedLocations } from "../data/managed_location/query";
import { useRemoveCardsMutation } from "../data/collection_remove/mutation";
import { mapError } from "../data/http/error";
import { useFetchPlacedLedger } from "../data/placement/query";
import {
  useMarkCardsPlacedMutation,
  useUnmarkCardsPlacedMutation,
} from "../data/placement/mutation";
import { ConfirmButton } from "../components/confirm_button";
import { CopyEntryForm, type RawCopyEntry } from "../components/copy_entry_form";
import { type RemovalSource, sourceKey } from "./remove_cards_sources";
import {
  type StagedEntry,
  chooseSource,
  exceedsOwned,
  needsSource,
  normalizeEntry,
  printingKey,
  refreshStaged,
  removeEntry,
  stageEntry,
  staleMessage,
  toRemoveCardsRows,
  toUnmarkPlacements,
  totalCards,
} from "./remove_cards_staging";

function sourceLabel(source: RemovalSource): string {
  const name = source.kind === "placed" ? source.name : "Unplaced";
  return `${name} (${source.available})`;
}

// Offered only when the copies could have come from more than one place: the
// pick decides which location's ledger row the removal takes (ADR 0023).
function SourceSelect(props: { entry: StagedEntry; onChoose: (source: RemovalSource) => boolean }) {
  const current = () => (props.entry.source === null ? "" : sourceKey(props.entry.source));
  const choose = (select: HTMLSelectElement) => {
    const source = props.entry.sources.find((candidate) => sourceKey(candidate) === select.value);
    // A refused pick leaves the line as it was; the select must say so too.
    if (source === undefined || !props.onChoose(source)) {
      select.value = current();
    }
  };

  return (
    <select
      class="staging-source"
      aria-label={`Where ${props.entry.setCode} ${props.entry.collectorNumber} was taken from`}
      value={current()}
      onChange={(event) => choose(event.currentTarget)}
    >
      <option value="" disabled>
        Taken from…
      </option>
      <For each={props.entry.sources}>
        {(source) => <option value={sourceKey(source)}>{sourceLabel(source)}</option>}
      </For>
    </select>
  );
}

function describeTaken(list: StagedEntry[]): string {
  return list
    .flatMap((entry) =>
      entry.source?.kind === "placed"
        ? [
            `${entry.quantity}x ${entry.setCode} ${entry.collectorNumber} (${entry.finish}·${entry.language}) from ${entry.source.name}`,
          ]
        : [],
    )
    .join(", ");
}

function StagedRow(props: {
  entry: StagedEntry;
  onChooseSource: (source: RemovalSource) => boolean;
  onRemove: () => void;
}) {
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
      <Show when={props.entry.sources.length > 1}>
        <SourceSelect entry={props.entry} onChoose={props.onChooseSource} />
      </Show>
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
  const fetchPlacedLedger = useFetchPlacedLedger();
  const unmarkMutation = useUnmarkCardsPlacedMutation();
  const markMutation = useMarkCardsPlacedMutation();
  const stageFromForm = async (raw: RawCopyEntry): Promise<boolean> => {
    const entry = normalizeEntry(raw);
    if (entry === null) {
      setFormError("Enter a set code, a collector number, and a quantity of at least 1.");
      return false;
    }
    setSuccessNote(null);
    let result;
    try {
      const [owned, decks, ledger] = await Promise.all([
        fetchOwnedCopies(entry.setCode, entry.collectorNumber),
        fetchManagedLocations(),
        fetchPlacedLedger(),
      ]);
      // Read after the await: another staging may have landed meanwhile.
      result = stageEntry(staged(), entry, owned, decks, ledger);
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

  const chooseLineSource = (entry: StagedEntry, source: RemovalSource): boolean => {
    const result = chooseSource(staged(), entry, source);
    if (!result.ok) {
      setFormError(result.message);
      return false;
    }
    setFormError(null);
    setStaged(result.list);
    return true;
  };

  // A 400 here means the collection moved since staging (ADR 0021): re-read
  // what's owned and where it's placed so the offending rows are marked,
  // rather than echoing the server's message.
  const handleStaleRejection = async () => {
    try {
      const [copiesByPrinting, ledger, decks] = await Promise.all([
        fetchCopiesByPrinting(staged()),
        fetchPlacedLedger(),
        fetchManagedLocations(),
      ]);
      const refreshed = refreshStaged(staged(), copiesByPrinting, ledger, decks);
      setStaged(refreshed);
      setSubmitError(staleMessage(refreshed));
    } catch (error) {
      setSubmitError(mapError(error).message);
    }
  };

  // The removal didn't happen, so the copies unmarked for it are still where
  // they were: record them back. Returns the message to show if even that
  // fails, since the ledger is then wrong in a way the collector must know.
  const restoreSources = async (list: StagedEntry[]): Promise<string | null> => {
    const placements = toUnmarkPlacements(list);
    if (placements.length === 0) {
      return null;
    }
    try {
      await markMutation.mutateAsync(placements);
      return null;
    } catch (error) {
      return `The removal failed, and recording the copies back failed too (${mapError(error).message}). Now counted as unplaced: ${describeTaken(list)}.`;
    }
  };

  // Unmarks the named locations first so the collection-changed reconcile
  // finds no excess to prune by its fallback order (ADR 0023). A failure
  // between the two calls leaves copies unplaced, which guidance re-files —
  // never a ledger row claiming a copy that's gone.
  const commit = async () => {
    setSubmitError(null);
    setSuccessNote(null);
    const list = staged();
    const count = totalCards(list);
    const placements = toUnmarkPlacements(list);
    if (placements.length > 0) {
      try {
        await unmarkMutation.mutateAsync(placements);
      } catch (error) {
        setSubmitError(mapError(error).message);
        return;
      }
    }
    try {
      const response = await mutation.mutateAsync({ rows: toRemoveCardsRows(list) });
      if (!response.decremented) {
        setSubmitError((await restoreSources(list)) ?? "The server rejected the staged cards.");
        return;
      }
      setStaged([]);
      setSuccessNote(`Removed ${count} card(s) from the collection.`);
    } catch (error) {
      const appError = mapError(error);
      const restoreFailure = await restoreSources(list);
      if (restoreFailure !== null) {
        setSubmitError(restoreFailure);
        return;
      }
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
                onChooseSource={(source) => chooseLineSource(entry, source)}
                onRemove={() => setStaged((list) => removeEntry(list, entry))}
              />
            )}
          </For>
        </ul>
        <ConfirmButton
          label={`Remove ${totalCards(staged())} card(s) from collection`}
          disabled={
            mutation.isPending ||
            unmarkMutation.isPending ||
            markMutation.isPending ||
            staged().some((entry) => exceedsOwned(entry) || needsSource(entry))
          }
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
