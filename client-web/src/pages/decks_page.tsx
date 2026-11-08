import { For, Show, createMemo, createSignal } from "solid-js";
import { A } from "@solidjs/router";
import { ConfirmButton } from "../components/confirm_button";
import { useCardQuery } from "../data/card_catalog/query";
import { CopyEntryForm, type RawCopyEntry } from "../components/copy_entry_form";
import { useFetchOwnedCopies } from "../data/collection/query";
import { mapError } from "../data/http/error";
import { useInventoryProjectionQuery } from "../data/inventory_planning/query";
import type { InventoryProjection } from "../data/inventory_planning/request";
import {
  useAddToManagedLocationMutation,
  useCreateManagedLocationMutation,
  useDeleteManagedLocationMutation,
  useRemoveFromManagedLocationMutation,
  useRenameManagedLocationMutation,
} from "../data/managed_location/mutation";
import { useManagedLocationsQuery } from "../data/managed_location/query";
import type { ManagedLocation } from "../data/managed_location/request";
import { randomUUID } from "../lib/uuid";
import { createMutationError } from "../lib/mutation_error";
import {
  type DeckRow,
  additionProblem,
  deckRowKey,
  deckRows,
  deckSummary,
  toManagedCopy,
} from "./deck_editing";
import { normalizeEntry } from "./remove_cards_staging";

// A management screen (ux-design): editing a deck list is desk work and the
// app's state is the truth (ADR 0022: membership is intent), so every change
// is pessimistic — shown once the server has it — and deleting a whole deck
// goes through ConfirmButton. Physically filing the cards into the deck box
// is the Place cards page's job, where a deck is just another location.

function CreateDeckForm() {
  const [name, setName] = createSignal("");
  const error = createMutationError();
  const mutation = useCreateManagedLocationMutation();

  const submit = (event: Event) => {
    event.preventDefault();
    error.clear();
    if (name().trim() === "") {
      error.report(new Error("Enter a name for the deck."));
      return;
    }
    mutation.mutate(
      { id: randomUUID(), name: name(), kind: "deck" },
      { onSuccess: () => setName(""), onError: (caught) => error.report(caught) },
    );
  };

  return (
    <>
      <form class="form-row" onSubmit={submit}>
        <label>
          New deck
          <input
            value={name()}
            onInput={(event) => setName(event.currentTarget.value)}
            placeholder="Mono-Red"
          />
        </label>
        <button type="submit" disabled={mutation.isPending}>
          Create deck
        </button>
      </form>
      <Show when={error.messageFor() !== null}>
        <p role="alert">{error.messageFor()}</p>
      </Show>
    </>
  );
}

function RenameDeckForm(props: { deck: ManagedLocation; onDone: () => void }) {
  const [name, setName] = createSignal(props.deck.name);
  const error = createMutationError();
  const mutation = useRenameManagedLocationMutation();

  const submit = (event: Event) => {
    event.preventDefault();
    error.clear();
    mutation.mutate(
      { id: props.deck.id, name: name() },
      { onSuccess: props.onDone, onError: (caught) => error.report(caught) },
    );
  };

  return (
    <>
      <form class="form-row" onSubmit={submit}>
        <label>
          Name
          <input value={name()} onInput={(event) => setName(event.currentTarget.value)} />
        </label>
        <button type="submit" disabled={mutation.isPending}>
          Save
        </button>
        <button type="button" onClick={() => props.onDone()}>
          Cancel
        </button>
      </form>
      <Show when={error.messageFor() !== null}>
        <p role="alert">{error.messageFor()}</p>
      </Show>
    </>
  );
}

function DeckCardRow(props: {
  deck: ManagedLocation;
  row: DeckRow;
  pending: boolean;
  onRemoveOne: (row: DeckRow) => void;
}) {
  const cardQuery = useCardQuery(() => ({
    set_code: props.row.set_code,
    collector_number: props.row.collector_number,
  }));
  const name = () => {
    if (cardQuery.isLoading) {
      return "Looking up…";
    }
    return cardQuery.data?.name ?? "Unknown card (not in catalog)";
  };

  return (
    <li class="placement-row">
      <span class="placement-card">
        <span class="placement-card-name">
          {props.row.quantity}x {name()}
        </span>
        <span class="placement-card-key">
          {props.row.set_code} {props.row.collector_number} ({props.row.finish}·{props.row.language}
          )
        </span>
        <Show when={props.row.missing > 0}>
          <span class="deck-missing">{props.row.missing} missing from the collection</span>
        </Show>
      </span>
      <button
        type="button"
        disabled={props.pending}
        aria-label={`Remove one ${name()} ${deckRowKey(props.row)} from ${props.deck.name}`}
        onClick={() => props.onRemoveOne(props.row)}
      >
        Remove one
      </button>
    </li>
  );
}

// Checks the addition against what's free before sending, so the usual
// outcome of a too-big request is a message naming the numbers rather than
// a server rejection.
function AddToDeckForm(props: { deck: ManagedLocation; decks: ManagedLocation[] }) {
  const error = createMutationError();
  const mutation = useAddToManagedLocationMutation();
  const fetchOwnedCopies = useFetchOwnedCopies();

  const submit = async (raw: RawCopyEntry): Promise<boolean> => {
    error.clear();
    const entry = normalizeEntry(raw);
    if (entry === null) {
      error.report(
        new Error("Enter a set code, a collector number, and a quantity of at least 1."),
      );
      return false;
    }
    try {
      const owned = await fetchOwnedCopies(entry.setCode, entry.collectorNumber);
      const problem = additionProblem(entry, owned, props.decks);
      if (problem !== null) {
        error.report(new Error(problem));
        return false;
      }
      await mutation.mutateAsync({ id: props.deck.id, copies: [toManagedCopy(entry)] });
      return true;
    } catch (caught) {
      error.report(caught);
      return false;
    }
  };

  return (
    <>
      <CopyEntryForm submitLabel="Add to deck" onSubmit={submit} />
      <Show when={error.messageFor() !== null}>
        <p role="alert">{error.messageFor()}</p>
      </Show>
    </>
  );
}

function DeckPanel(props: {
  deck: ManagedLocation;
  decks: ManagedLocation[];
  projection: InventoryProjection | undefined;
}) {
  const [renaming, setRenaming] = createSignal(false);
  const error = createMutationError();
  const removeMutation = useRemoveFromManagedLocationMutation();
  const deleteMutation = useDeleteManagedLocationMutation();
  const rows = createMemo(() => deckRows(props.deck, props.projection));

  const removeOne = (row: DeckRow) => {
    error.clear();
    removeMutation.mutate(
      { id: props.deck.id, copies: [{ ...row, quantity: 1 }] },
      { onError: (caught) => error.report(caught) },
    );
  };

  const deleteDeck = () => {
    error.clear();
    deleteMutation.mutate(props.deck.id, { onError: (caught) => error.report(caught) });
  };

  return (
    <section class="deck-panel">
      <Show
        when={renaming()}
        fallback={
          <div class="form-row">
            <h3>
              {props.deck.name} <span class="hint">{deckSummary(rows())}</span>
            </h3>
            <button type="button" onClick={() => setRenaming(true)}>
              Rename
            </button>
            <ConfirmButton
              label="Delete deck"
              ariaLabel={`Delete deck ${props.deck.name}`}
              disabled={deleteMutation.isPending}
              onConfirm={deleteDeck}
            />
          </div>
        }
      >
        <RenameDeckForm deck={props.deck} onDone={() => setRenaming(false)} />
      </Show>
      <Show when={error.messageFor() !== null}>
        <p role="alert">{error.messageFor()}</p>
      </Show>
      <Show when={rows().length > 0} fallback={<p class="hint">No cards in this deck yet.</p>}>
        <ul class="placement-list">
          <For each={rows()}>
            {(row) => (
              <DeckCardRow
                deck={props.deck}
                row={row}
                pending={removeMutation.isPending}
                onRemoveOne={removeOne}
              />
            )}
          </For>
        </ul>
      </Show>
      <AddToDeckForm deck={props.deck} decks={props.decks} />
    </section>
  );
}

export function DecksPage() {
  const decksQuery = useManagedLocationsQuery();
  const projectionQuery = useInventoryProjectionQuery();
  const decks = () => decksQuery.data ?? [];
  // Keyed by id, not by the deck objects: each refetch brings fresh objects,
  // and <For> keyed on those would remount every panel — dropping an open
  // rename form — whenever any deck changed (client-web/AGENTS.md).
  const deckIds = createMemo(() => decks().map((deck) => deck.id));
  const deckById = (id: string) => decks().find((deck) => deck.id === id);

  return (
    <section>
      <h2>Decks</h2>
      <p class="hint">
        A deck keeps its cards out of your binders: they're taken before any location rule runs, so
        they never appear in a binder or bulk. A deck only names which copies it holds — no
        deck-building help. Once a deck lists its cards, file them into the deck box on{" "}
        <A href="/placement">Place cards</A>. Deleting a deck sends its cards back to wherever your
        rules put them.
      </p>
      <CreateDeckForm />
      <Show when={decksQuery.isLoading}>
        <p>Loading decks...</p>
      </Show>
      <Show when={decksQuery.isError}>
        <p role="alert">{mapError(decksQuery.error).message}</p>
      </Show>
      <Show when={decksQuery.isSuccess && decks().length === 0}>
        <p>No decks yet.</p>
      </Show>
      <For each={deckIds()}>
        {(id) => (
          <Show when={deckById(id)}>
            {(deck) => (
              <DeckPanel deck={deck()} decks={decks()} projection={projectionQuery.data} />
            )}
          </Show>
        )}
      </For>
    </section>
  );
}
