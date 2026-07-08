# Contract (Skir)

Generated files live in `server/src/shared/driver/skir/skirout/` and `client-web/src/data/skirout/`. **Never edit them directly** — change `*.skir` files here then run `just skir-gen`.

## Compatibility Policy

The contract is intentionally unversioned ([ADR 0002](../docs/decisions/0002-unversioned-contract-atomic-breaking-changes.md)). Breaking contract changes are only allowed when backend and frontend adaptations are delivered in the **same PR**:

- Update contract source files in `skir-src/` and regenerate (`just skir-gen`).
- Update the contract snapshot `skir-snapshot.json` (`just skir-snapshot`).
- Include the corresponding `server/src/<context>/driver/skir/` mapping changes.
- Include the corresponding frontend request/query/mutation changes.
- Verify with `just skir-check` (format + snapshot alignment).
