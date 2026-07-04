export const SORT_OPTIONS = [
  { value: "card_name", label: "Card name" },
  { value: "set_code", label: "Set" },
  { value: "quantity", label: "Quantity" },
] as const;

export const GROUP_OPTIONS = [
  { value: "location_name", label: "Location" },
  { value: "set_code", label: "Set" },
] as const;

// How many copies of a matching card a rule claims — the cascade selector DSL.
export const SELECTOR_OPTIONS = [
  { value: "all", label: "All copies" },
  { value: "first_per_printing", label: "First copy per printing" },
  { value: "first_per_oracle", label: "First copy per card (oracle)" },
] as const;
