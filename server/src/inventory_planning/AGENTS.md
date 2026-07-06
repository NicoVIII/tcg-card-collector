# Inventory Planning

Domain vocabulary (RuleCascade, Predicate, LocationTarget, BulkSpec) is defined in [docs/dev/domain-ubiquitous-language.md](../../../docs/dev/domain-ubiquitous-language.md).

Users configure rules through three small DSLs, each owned by one domain parser:

- `domain/card_predicate.gleam` — match expression (`and`-joined clauses)
- `domain/location_target.gleam` — location-name placeholders (`{set_code}`, ...)
- `domain/sort_spec.gleam` — comma-separated sort keys

The parsers and their unit tests (`server/test/inventory_planning/unit/domain/`) are the syntax reference — don't duplicate the grammar in docs.

**UI hint sync (unenforced):** the inventory page (`client-web/src/pages/inventory_page.tsx`) restates the DSL surface in user-facing hint paragraphs. Any change to expression syntax, placeholders, or sort keys must update those hints too.
