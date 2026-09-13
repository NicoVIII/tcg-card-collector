// How many copies of a matching card a rule claims — the cascade selector DSL.
export const SELECTOR_OPTIONS = [
  { value: "all", label: "All copies" },
  { value: "first_per_printing", label: "First copy per printing" },
  { value: "first_per_oracle", label: "First copy per card (oracle)" },
] as const;
