# AGENTS.md

## Stack

Gleam backend (Erlang target) + SolidJS/TypeScript frontend, connected by a Skir contract (contract-first RPC with code generation for both sides).

## Task Runner

`just` with `::` module scoping. Key commands:

```sh
just dev              # run backend + frontend
just check            # all checks (skir + server + client-web)
just server::test     # Gleam unit tests
just client-web::test # Vitest tests
just skir-gen         # regenerate code from skir-src/
```

Run `just --list` for the full list.