# Backend Architecture Lint

The backend follows strict layer boundaries inspired by full-house.

## Layer Rule Matrix

- domain -> domain, common
- application -> application, domain, common
- infrastructure -> infrastructure, application, domain, common
- driver -> driver, application, domain, common
- common -> common
- composition/root -> any layer (wiring-only)

## Enforcement

- Rule framework: `server/vendor/gleam-libs/packages/glinter_arch` (git submodule)
- Project-specific config (categorize/is_allowed/describe): `server/test/lint.gleam`
- Runtime architecture gate: `just server::lint-check` (`gleam run -m lint`)

## Exception Policy

Exceptions are declared in the `allowed_cross_bc` list in `server/test/lint.gleam`.

Allowed:

- Temporary, explicit one-to-one exceptions with clear refactoring intent.

Not allowed:

- Wildcards or blanket layer bypasses.
- Permanent exceptions without a follow-up task.
