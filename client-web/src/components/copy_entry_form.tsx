import { For, createSignal } from "solid-js";
import {
  DEFAULT_FINISH,
  DEFAULT_LANGUAGE,
  FINISHES,
  LANGUAGES,
  type Finish,
  type Language,
} from "../data/collection/copy_kind";

// What the form hands its owner, still raw: the owner normalizes and checks
// it the way its own flow needs to.
export type RawCopyEntry = {
  setCode: string;
  collectorNumber: string;
  finish: Finish;
  language: Language;
  quantity: number;
};

type Props = {
  submitLabel: string;
  // Resolves true when the entry was taken: the collector number and
  // quantity then clear and the number field is refocused, while the set
  // code sticks — the "open a booster" rhythm of entering one set's cards.
  onSubmit: (entry: RawCopyEntry) => boolean | Promise<boolean>;
};

// One kind of copy — set, number, finish, language, quantity — as the Add
// cards, Remove cards, and deck panels all enter it.
export function CopyEntryForm(props: Props) {
  const [setCode, setSetCode] = createSignal("");
  const [collectorNumber, setCollectorNumber] = createSignal("");
  const [finish, setFinish] = createSignal<Finish>(DEFAULT_FINISH);
  const [language, setLanguage] = createSignal<Language>(DEFAULT_LANGUAGE);
  const [quantity, setQuantity] = createSignal("1");
  let collectorNumberInput: HTMLInputElement | undefined;

  const submit = async (event: Event) => {
    event.preventDefault();
    const taken = await props.onSubmit({
      setCode: setCode(),
      collectorNumber: collectorNumber(),
      finish: finish(),
      language: language(),
      quantity: Number.parseInt(quantity(), 10),
    });
    if (taken) {
      setCollectorNumber("");
      setQuantity("1");
      collectorNumberInput?.focus();
    }
  };

  return (
    <form class="form-row" onSubmit={(event) => void submit(event)}>
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
      <button type="submit">{props.submitLabel}</button>
    </form>
  );
}
