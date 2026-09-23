import { createSignal, createEffect } from "solid-js";
import type { CardFilter } from "../lib/card_filter";

type Props = {
  filter: CardFilter;
  onSearch: (filter: CardFilter) => void;
};

// Submits on Enter/click rather than live-typing: a name filter scans the
// catalog's ~115k rows, so filtering on every keystroke would hammer the
// server for no benefit over one request per finished search term.
export function CardSearchForm(props: Props) {
  const [name, setName] = createSignal("");
  const [setCode, setSetCode] = createSignal("");

  // Seeds the fields on mount and keeps them in sync when the filter changes
  // from outside the form (e.g. a back/forward navigation restoring a
  // different URL).
  createEffect(() => {
    setName(props.filter.name);
    setSetCode(props.filter.set_code);
  });

  const submit = (event: Event) => {
    event.preventDefault();
    props.onSearch({ name: name(), set_code: setCode() });
  };

  const clear = () => {
    setName("");
    setSetCode("");
    props.onSearch({ name: "", set_code: "" });
  };

  return (
    <form class="form-row" onSubmit={submit}>
      <label>
        Name
        <input
          value={name()}
          onInput={(event) => setName(event.currentTarget.value)}
          placeholder="Lightning Bolt"
        />
      </label>
      <label>
        Set
        <input
          value={setCode()}
          onInput={(event) => setSetCode(event.currentTarget.value)}
          placeholder="lea"
          size={6}
        />
      </label>
      <button type="submit">Search</button>
      <button type="button" onClick={clear}>
        Clear
      </button>
    </form>
  );
}
