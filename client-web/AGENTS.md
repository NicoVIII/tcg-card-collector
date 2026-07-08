# Web Client (SolidJS + TypeScript)

Tooling runs through bun via the justfile (`just client-web::check`, `::test`, `::dev`). Formatting is oxfmt, linting is eslint + oxlint, tests are Vitest (node environment).

## Data Layer (`src/data/`)

One directory per backend capability, each split into three files:

- `request.ts` — plain async functions wrapping `skirClient.invokeRemote` with the generated skirout types; maps wire types (camelCase) to local snake_case types at this boundary.
- `query.ts` / `mutation.ts` — TanStack Solid Query hooks (`use*Query` / `use*Mutation`) built on the request functions.

Rules:

- **Pages/components never call `skirClient` directly** — they consume the hooks.
- **Query keys come from `data/query-keys/factory.ts`** — never inline key arrays; the factory is the single source for cache identity (and has tests).
- Single RPC client in `data/http/skir_rpc.ts`; QueryClient defaults in `data/tanstack_helper.ts`.
- Per-card lookups batch through `@yornaath/batshit` (`data/card_catalog/batcher.ts`) — follow that pattern for new N+1-shaped reads.
- `data/settings/` is deliberate UI-facing naming: it wraps the backend's inventory_planning planning-preferences RPCs. Frontend data dirs follow UI concepts, not backend contexts, when they diverge.
- `src/data/skirout/` is generated — **never edit**; change `skir-src/` and run `just skir-gen`.

## Structure & Testing

- `pages/` (route components, wired in `routes.ts` via @solidjs/router), `components/` (shared UI). Filenames are snake_case.
- Tests are colocated `*.test.ts` next to the module. Testable logic is extracted into plain non-JSX modules (e.g. `pages/import_deckstats.ts`, `routes.ts`) so it runs in the node environment — no component/DOM tests currently; don't add DOM-dependent logic to `.ts` modules.
- **DSL hint sync (unenforced):** the hint paragraphs in `pages/inventory_page.tsx` restate the rule-DSL surface (placeholders, expression syntax, sort keys) whose source of truth is the parsers in `server/src/inventory_planning/domain/`. Don't change hint content from the frontend side alone — verify against the parsers, and keep both in sync when either changes.
