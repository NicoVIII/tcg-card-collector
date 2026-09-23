# 0017 — Language rule expression and DSL-wide `!=`

- Status: accepted
- Date: 2026-09-23

## Context

ADR 0010 threaded language all the way through the model: it's a shared
kernel type, the collection stores quantity per CopyKey, the placement ledger
keys on it, `PlannedCard` carries it, and Inventory Planning already has an
ordering policy for it (`compare_language_en_first`). What's missing is the
planning-side vocabulary: `Predicate` has no language clause, `SortKey` has no
`language` token, and the DSL has no negation. Without negation, "everything
except English" can only be written by enumerating the other 17 codes, or by
letting those copies fall through to bulk — which only works while
non-English is the *only* thing left over (#112).

`Predicate` deliberately has no `or` and no nesting this milestone. Any
negation design has to either respect that or explain why it doesn't, and it
has to say what happens when a negated clause meets a card the catalog
doesn't know anything about — `color_identity` and `type` can be absent
(ADR 0008's cascade precedent: an unmatched clause is `False`, so the card
cascades to a later rule), and a naive negation would flip that to `True`.

## Considered options

- **Negation spelling**
  - *`!=` on equality clauses* — won. It's the issue's headline spelling and
    survives a new Scryfall language code being added; `language != en` reads
    as one idea, not "apply `not` to `language = en`".
  - *`not (...)`* — lost. It reopens the nesting `Predicate` deliberately
    avoids, for a form that only ever needs to negate a single equality.
- **`!=` scope**
  - *DSL-wide, on every attribute that already takes `=`* (`set_code`,
    `color_identity`, `type`, `finish`, plus the new `language`) — won. A
    generic operator that only worked on one attribute would be a language
    clause with `!=` syntax, not a DSL feature; the parser change (a `NotEq`
    token, one dispatch arm) is the same size either way.
  - *Language-only* — lost, for the reason above.
- **Predicate representation**
  - *Negated single-value variants* (`SetCodeIsNot`, `ColorIdentityIsNot`,
    `CardTypeIsNot`, `FinishIsNot`, `LanguageIsNot`) — won. Each variant
    handles the unknown-enrichment case explicitly in `matches` (absent stays
    `False`, not flipped), every value renders back to `!=` DSL text with no
    ambiguity, and the type still allows no nesting.
  - *`Not(Predicate)` wrapper* — lost. `matches` would need an
    "is this attribute known" side channel to keep `Not(False)` from becoming
    `True` for an absent `color_identity`/`type`, and the wrapper's type
    doesn't stop someone building `Not(And(...))` or `Not(Not(...))`, states
    the DSL has no syntax for and `parse` would have to reject by hand — the
    nesting `Predicate`'s doc comment says this milestone doesn't have.
  - *A `negated: Bool` field on the existing `_In` list variants, plus
    `not in (...)`* — lost. More expressive (`language not in (en, ja)`), but
    the issue only asks for `!=` on a single value; `not in` is a follow-up if
    someone needs it, not a cost this change should carry.
- **Language clause shape**
  - *One `LanguageIn(List(Language))` variant covering both `= xx` and
    `in (...)`* — won, following the `FinishIn` precedent (#71, ADR 0010):
    one variant, rendering a single value back as `= xx`.
  - *Separate `LanguageIs`/`LanguageIn`* — lost. `LanguageIs` would just be
    `LanguageIn([x])`.

## Decision

- `!=` is spelled as `attr != value` and applies to every attribute that
  already takes `=`: `set_code`, `color_identity`, `type`, `finish`, and the
  new `language`. It does not apply to `rarity`, which only takes `>=`.
- Each gets its own negated `Predicate` variant
  (`SetCodeIsNot`/`ColorIdentityIsNot`/`CardTypeIsNot`/`FinishIsNot`/
  `LanguageIsNot`), not a `Not` wrapper or a negated-list field. `matches` on
  `ColorIdentityIsNot`/`CardTypeIsNot` is `False` for a card whose enrichment
  is absent, same as the positive clauses — negation never turns "the catalog
  doesn't know" into a match.
- `language` gets a match clause (`LanguageIn`, covering `= xx` and
  `in (...)`) and a `SortKey` token (`language`), ordered by the existing
  `compare_language_en_first` policy. Language is never absent (ADR 0010), so
  the language clauses have no unknown-enrichment case to handle.

## Consequences

- The DSL keeps its "no nesting, no or" shape; negation is five more
  `Predicate` variants and one more token, not a second parser mode.
  `.claude/skills/domain-design/SKILL.md`'s note that a language rule
  expression is ADR-weight is satisfied by this record.
- `!=` costs five more `matches`/`to_string` arms now and one more per
  attribute a future `=` clause adds — accepted as the price of avoiding a
  wrapper type that mishandles absence.
- "Everything except English" (`language != en`) is expressible without
  enumerating the other 17 codes, and a new Scryfall language code added
  later doesn't break existing `!=` rules.
- `not in (...)` (negating a list of more than one value) is still
  inexpressible; the workaround is one `!=` clause per excluded value
  and-ed together, or falling back to bulk. Nobody has asked for it yet.
