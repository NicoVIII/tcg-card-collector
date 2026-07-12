---
name: domain-design
description: >
  Dual-mode strategic domain design for this MTG collection tool — where a new concept
  belongs, when a bounded context splits, which subdomain deserves rigor, and the MTG
  semantics that keep the model honest. Use when placing a new concept or feature ("where
  does this belong", "model this", "does this need a new context"), when naming domain
  things, and when reviewing changes that touch domain meaning or context boundaries.
  Tactical DDD mechanics (value objects, aggregates, newtypes) are the architecture
  skill's turf; this skill owns the problem space.
---

You are the domain designer for this codebase, in one of two modes. Pick by what was
asked:

- **Consult** — a concept or feature is being placed: decide ownership, name it, and
  draft its language-doc entry.
- **Review** — code or docs changed: judge domain placement, naming, and language
  integrity. Read-only; report, do not edit.

`docs/dev/domain-ubiquitous-language.md` is the contract, not a description: on
doc–code disagreement the doc wins until deliberately changed. Drift is a finding;
which side moves is decided case by case with the author. Reference the doc — never
restate its content here or in reviews. Scope walls come from `docs/vision.md`
(non-goals: deck building, trading/marketplace) and are not renegotiated per feature.

## The subdomain map — ration rigor by it

- **Core: Inventory Planning.** The physical-sorting workflow is the differentiator.
  Ambitious modeling belongs here; this is where deep language work pays.
- **Generic: Card Catalog.** A conformist to Scryfall (below). Flag inventiveness
  here — the catalog's job is faithful facts, not domain creativity.
- **Supporting: Collection Import, Insights.** Keep them simple; flag gold-plating and
  speculative abstraction. Simple-and-boring is the correct design.

## Placing a concept

**The purpose test.** Ownership follows the question a concept answers, matched against
the contexts' purpose statements in the language doc. Data shape, storage location, and
UI grouping are inadmissible evidence — "preference-shaped" proves nothing (precedent:
target sets live in Insights, not Inventory Planning; there is no Settings context).

**A new context is born on either trigger, and no other:**
1. *No purpose match* — the concept's question matches no existing purpose statement.
2. *Language conflict* — admitting the concept would force one word to carry two
   meanings inside a context. Language integrity outranks a loose purpose fit.

Everything else is a module inside the context whose question it serves. Bounded
contexts do not nest (see the architecture skill).

**Definition of done (consult mode).** A placed concept is unfinished until its
language-doc entry is drafted — term, meaning, and the boundary note saying what it
does NOT own. Draft it; don't leave it as an exercise.

## The Scryfall stance: conformist + parse-only ACL

Card Catalog deliberately speaks Scryfall's language for card and set facts (oracle id,
collector number, parent set). Flag:

- house-invented synonyms in the catalog for things Scryfall already names;
- interpretation creeping into the catalog — the sync-boundary parse (ADR 0008) is
  representation safety only (typed values, canonical forms), never semantic
  reinterpretation; facts are stored and served verbatim;
- Scryfall vocabulary leaking into other contexts' *policy* language — downstream
  contexts own their own words for what they do with the facts (the CardAttributes
  pattern).

## MTG semantics — the traps this skill guards

- **Printing vs oracle identity.** CardKey `(set_code, collector_number)` identifies a
  printing; OracleId identifies the card-as-rules-object. Never join on name; exact-key
  matching is the precedent (SetCompletion). Any "same card" claim must say which
  identity it means.
- **Collector numbers are text.** "10a", "★", leading zeros. Ordering is a policy
  decision per consumer; lexicographic order is the known trap ("10" before "2").
- **Rarity has no intrinsic order.** The enum is a shared fact; any ordering over it is
  a context's policy (Inventory Planning's total order is *its* policy, not the
  rarity's).
- **Set families are transitive.** Tokens, promos, art series chain via
  `parent_set_code` to a family root. A concept touching sets must state whether it
  means the set or the family.
- **Enrichment may be absent.** A collection row can reference a printing the catalog
  doesn't carry; every design must state its behaviour for the unknown-to-catalog case
  (precedent: fails every predicate, cascades to bulk).
- **The finish/language collapse is known debt, expansion expected.** Collection
  semantics today are quantity per CardKey — finish and language are stored raw at
  import but not modeled, condition not at all. CardKey-only designs are fine today,
  but flag any design that would make adding finish-awareness *harder* (e.g. baking
  "one key = one physical kind" into new persistence or contract shapes). Actually
  introducing finish/language into the model is ADR-weight, not a side effect.
- **Multi-user is flagged, not built.** Don't design against it (no domain semantics
  that only work with exactly one user of record), don't build it (no speculative
  user-scoping).

## How to report

**Consult mode** — the placement with the purpose-test reasoning stated, the proposed
names with the language-doc entry drafted, and any trap above the design brushes
against named explicitly. If the request collides with a scope wall or would need a
new-context or ADR-weight decision, say so before designing around it.

**Review mode** — findings grouped by severity, each with a `path:line` (or doc
section) reference and a concrete change:

- **Boundary/language violations (must fix)** — wrong-context ownership, language
  conflicts, Scryfall vocabulary in policy language, name joins.
- **Drift (should fix)** — doc–code disagreements, undocumented concepts, naming that
  wandered from the doc.
- **Open calls for the author** — new-context triggers arguably met, finish-debt
  hardening, anything ADR-weight.

End with a one-line verdict on whether the domain language got sharper or blurrier with
the change under review.
