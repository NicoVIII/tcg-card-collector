# Web Client (SolidJS + TypeScript)

Tooling runs through bun via the justfile (`just client-web::check`, `::test`, `::dev`). Formatting is oxfmt, linting is eslint + oxlint, tests are Vitest (node environment).

TypeScript is split on purpose: `@typescript/native` (TS 7) provides `tsc` for `type-check`, while the `typescript` name is aliased to `@typescript/typescript6` because typescript-eslint needs the JS API that TS 7 dropped. Collapse the alias only once typescript-eslint supports TS 7.

The eslint config carries the code-shape floor — top-down order (`@typescript-eslint/no-use-before-define`), `complexity`, `max-depth` — at the backend's glinter thresholds. Escape hatch: `// eslint-disable-next-line <rule> -- <reason>` on the line above.

## Data Layer (`src/data/`)

One directory per backend capability, each split into three files:

- `request.ts` — plain async functions wrapping `skirClient.invokeRemote` with the generated skirout types; maps wire types (camelCase) to local snake_case types at this boundary.
- `query.ts` / `mutation.ts` — TanStack Solid Query hooks (`use*Query` / `use*Mutation`) built on the request functions.

Rules:

- **Pages/components never call `skirClient` directly** — they consume the hooks.
- **Query keys come from `data/query-keys/factory.ts`** — never inline key arrays; the factory is the single source for cache identity (and has tests).
- Single RPC client in `data/http/skir_rpc.ts`; QueryClient defaults in `data/tanstack_helper.ts`.
- Per-card lookups batch through `@yornaath/batshit` (`data/card_catalog/batcher.ts`) — follow that pattern for new N+1-shaped reads.
- `src/data/skirout/` is generated — **never edit**; change `skir-src/` and run `just skir-gen`.
- **View state that should survive a reload goes through `useSearchParams`** (`@solidjs/router`), not a bare signal or browser storage — a reload or a shared link should land the user back where they were (precedent: the open-location focus in `pages/placement_page.tsx`).
- A data dir may hold a derivation module beyond the `request`/`query`/`mutation` trio when logic that once lived server-side moves to the client. `data/placement/guidance.ts` folds the cached projection + the placed ledger into placement guidance (see [ADR 0006](../docs/decisions/0006-placement-guidance-derived-client-side.md)) — such modules are pure and vitest-covered, and anything that changes the projection must invalidate `inventoryProjection`.

## Structure & Testing

- `pages/` (route components, wired in `routes.ts` via @solidjs/router), `components/` (shared UI). Filenames are snake_case.
- Tests are colocated `*.test.ts` next to the module. Testable logic is extracted into plain non-JSX modules (e.g. `pages/import_deckstats.ts`, `routes.ts`) so it runs in the node environment — no component/DOM tests; don't add DOM-dependent logic to `.ts` modules. The one exception is `routes.test.ts`, which opts into happy-dom via a file pragma because `routes.ts` imports the page components.
- **Pages own JSX and signal wiring only.** Parsing, staging state, and derivations live in a colocated plain `.ts` module (`pages/placement_session.ts`, `pages/add_cards_staging.ts` are the precedent) — that is what keeps them node-testable and the page readable.
- **Page plumbing that repeats becomes a helper**: the `onError: mapError(...).message` pattern has been extracted to `lib/mutation_error.ts` (`createMutationError`, scoped so more than one form on a page can each show its own error) and adopted in `placement_page.tsx`, `insights_page.tsx`, and `inventory_page.tsx`. `catalog_page.tsx`, `add_cards_panel.tsx`, and `collection_import_page.tsx` wrap the message in richer feedback objects and are left alone for now — a future occurrence there is a separate call, not an oversight. The seed-once `createEffect` pattern is down to its one remaining occurrence (the bulk-spec form in `inventory_page.tsx`, seeding from an async query); `inventory_page.tsx`'s rule-row editor no longer needs it — its edit form mounts fresh per open row and seeds from props at creation instead.
- **Destructive actions never fire on one click.** An app-first destructive action (deleting an inventory rule or target set, replacing the whole collection on import) goes through `components/confirm_button.tsx` — first click arms it to "Confirm?", the second runs it, and it disarms itself on blur, Escape, or a timeout (`lib/confirm_arm.ts`, timeout is the touch-device safety net where a tap often never focuses the button). A world-first bulk action (placement's "Mark all placed") stays optimistic instead — it fires immediately but offers a batch undo as a single unit (`placement_page.tsx`'s `lastMarkAll`, backed by `pages/placement_session.ts`'s `tickAll`/`untickAll`) rather than blocking with a confirm. See the ux-design skill for which posture a new mutation should take.
- `playwright` (devDependency) is the QA skill's disposable driver for exploratory verification (`.claude/skills/qa/`) — NOT a test layer. Scripts are throwaway; never commit browser tests or wire Playwright into CI (the e2e deferral in `server/test/AGENTS.md` stands).
- **DSL hint sync (unenforced):** the hint paragraphs in `pages/inventory_page.tsx` restate the rule-DSL surface (placeholders, expression syntax, sort keys) whose source of truth is the parsers in `server/src/inventory_planning/domain/`. Don't change hint content from the frontend side alone — verify against the parsers, and keep both in sync when either changes.
