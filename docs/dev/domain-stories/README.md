# Domain Stories

Each story walks one collector goal step by step and names the command, query, or
client-side derivation that carries each step. They exist to argue about the use-case
surface: a step with no handler is a missing use case, a handler no step reaches is
speculative or dead.

Terms come from [domain-ubiquitous-language.md](../domain-ubiquitous-language.md) and
are used, never redefined, here.

## Format

- **Scope line**: always *as-is* (what the code does today), *fine-grained*, and
  *digitalized* (the App is an actor — that is what lets a step map to a handler).
- **One file per collector goal**; variants of the same goal are further numbered
  stories in that file.
- **Sentences**: numbered, `Actor — activity — work object`, at domain level. UI
  mechanics (buttons, pages) only where the distinction changes which handler runs.
- **Handler links** end the step, in exactly one of these forms:
  - `[cmd: <context>/<command>]` — `server/src/<context>/application/commands/<command>/`
  - `[query: <context>/<query>]` — `server/src/<context>/application/queries/<query>/`
  - `[derived: <path>]` — client-side derivation over query results (ADR 0006 and
    successors), path relative to the repo root
- **Diagram** (optional for a linear story): a Mermaid `sequenceDiagram` above the
  sentences, participants Collector, Location (physical), App, so the physical/digital
  split is visible. `autonumber` must match the sentence numbers, which means one
  activity per sentence. No handler names and no gaps — the sentences are the source
  of truth and the only place links and gaps live.
- **Gaps**: a `> **Gap:**` blockquote right under the step it interrupts, linking its
  issue, or saying `untracked` until one is filed.
- **Coverage** section last: which handlers of the context the file references, and
  which remain owed by other stories.
