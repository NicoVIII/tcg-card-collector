# Infrastructure Layer

Two sub-layers:

- `adapters/` — port implementations. Mirrors the `application/` structure: `adapters/commands/<domain>/<command>/`, `adapters/queries/<domain>/<query>/`, or `adapters/<context>/` for contexts not yet split into commands/queries.
- `stores/` — reusable SQLite access, organized by bounded context (`stores/<context>/`). Shared by adapters within the same context.

When adding a new use case, place its adapter at the path that mirrors the application layer, and its store logic in `stores/<context>/`.
