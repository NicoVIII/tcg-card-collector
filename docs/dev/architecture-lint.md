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

- Rule implementation reference: `server/linting/src/rules/depends_only_on.gleam`
- Runtime architecture gate: `server/linting/check_architecture.sh`
- Backend quality entrypoint: `just check-backend`

## Exception Policy

Exceptions are documented in `server/linting/architecture_exceptions.txt`.

Allowed:

- Temporary, explicit one-to-one exceptions with clear refactoring intent.

Not allowed:

- Wildcards or blanket layer bypasses.
- Permanent exceptions without a follow-up task.

Exception format:

`source/module -> target/module`
