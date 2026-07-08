# Architecture Decision Records

Decision records based on [MADR](https://adr.github.io/madr/), minimal
template. The division of labor:

- **ADRs (here)** — immutable snapshots of one decision each: the context at
  the time, the alternatives considered, why they lost, and the consequences.
  Never edited after acceptance — a changed mind gets a *new* ADR that
  supersedes the old one.
- **Living docs** ([architecture.md](../dev/architecture.md), the AGENTS.md
  files) — the current state of the art. They keep only enough "why" to make a
  rule understandable and link to the ADR for the full story.
- **Commit messages** — the micro-why of individual changes.

## When to write one

Write an ADR when a decision had **real alternatives** and is either expensive
to reverse or likely to be questioned again (by a reviewer, an agent, or
future you). Don't write one for conventions with no contest — that's noise.
Settled decisions in this directory should not be relitigated in review;
propose a superseding ADR instead.

## Mechanics

- Files are `NNNN-short-title.md`, numbered sequentially. Copy
  [adr-template.md](adr-template.md).
- Statuses: `proposed` → `accepted`, later possibly `superseded by
  [NNNN](NNNN-...)` (the only edit an accepted ADR may receive).
- ADRs are archival context, not operating rules: agents should read one when
  touching its area (follow links from the living docs), not load them all
  routinely.

Records 0001–0005 were backfilled on 2026-07-08 from existing documentation
and git history; their dates are the approximate original decision dates.
