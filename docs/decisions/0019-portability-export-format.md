# 0019 — Exported data is one versioned JSON document, owned by a new Portability context

- Status: accepted
- Date: 2026-09-25

## Context

v0.2.0 promises that everything hand-made in the app — collection, location
rules, bulk spec, set targets, and the placed ledger — can be exported to a
file and imported into another install without loss (`docs/vision.md`). #116
scoped the first slice of that (the collection alone) as a CSV mirroring
`ImportCollectionRow`. #133 then asked where such a file states its own
format version, since ADR 0002's atomic-breaking-change policy assumes
client and server always ship together — an exported file doesn't, so a
contract change ADR 0002 allows could silently break every file already
written to disk. #119 plans to widen the same export to rules, bulk spec,
targets, and the ledger, and raised the same container-format question for
that superset.

All three issues are really one design: what shape does the whole exported
document have, who owns that shape, and how does it carry its own version.
This ADR settles that ahead of implementing any of them.

## Considered options

- **Container format**
  - *One JSON document, all sections under one file* — won. One version, one
    schema, one set of frozen fixtures (#133). Fits everything the milestone
    needs, including the ledger and rule expressions, which a flat CSV
    cannot represent. No new runtime dependency (`gleam_json` is already a
    server dependency; the browser has `JSON.parse`).
  - *CSV per concern, zipped together* — lost. A CSV can't naturally carry
    the version column's own invariant (every row must agree, and an empty
    file carries no version at all) or nested shapes like a rule expression.
    Re-zipping after a hand edit is a new way to corrupt the file that a
    single JSON document doesn't have.
  - *YAML* — lost. YAML's implicit typing can silently turn a collector
    number like `017` into the number 17 on a hand edit — exactly the
    silent identity change the v0.2.0 promise rules out.
  - *TOML* — lost. Repeats a table header per array entry; unworkable at the
    tens-of-thousands-of-rows scale a real collection reaches.

- **Where the version lives**
  - *A single top-level `format_version` field* — won. One source of truth,
    present even when the collection is empty, and it is exactly what
    import checks before parsing anything else.
  - *A version column repeated on every collection row* (the original CSV
    plan) — lost. Every row must then be checked for agreement, and an
    empty export has no row to carry it at all.

- **Who owns the document shape**
  - *A new `portability` context reads every other context through its
    `driver/gleam` facade and assembles/parses the whole document* — won.
    The file format is a product in its own right: one version, one schema,
    one set of frozen fixtures, and one place that can check relationships
    between sections (a placed-ledger row naming a collection copy that no
    longer exists). The trade is `allowed_cross_bc` pairs from
    `portability` to each context it reads, one per section added.
  - *Every context supplies its own section, portability only assembles
    them* (a `Section` capability each context implements, portability
    depending on none of them) — lost. It reads well against ADR 0011's
    event-bus precedent (only `bootstrap/` knows every context), but it
    scatters the file format across contexts: a version per section, a
    fixture set per section, and no single place left that can check a
    relationship spanning two sections. Import's cross-section atomicity is
    unsolved either way, so it isn't what decided this.

- **Version identity**
  - *An integer decoupled from the app version, starting at 1* — won. The
    file format changes far less often than the app does; tying it to the
    app version would make every release look like a new format and need a
    version-to-format lookup table on import.

## Decision

- Exported data is one JSON document: a `format` marker, a top-level integer
  `format_version`, an `exported_on` date, and one key per bounded context
  that has hand-made data to export. #116 ships the first key, `collection`;
  #119 adds `inventory_planning` and `insights` sections under the same
  `format_version: 1` before v0.2.0 ships. `format_version` bumps only when
  a section's *shape* changes in a way #117's importer must branch on — a
  new section key does not by itself bump it, since old importers already
  ignore unknown keys they don't parse.
- A new bounded context, **Portability**, owns the document: its version,
  its JSON Schema, and its two doors (Skir `ExportData` / REST
  `GET /api/export`). It reads each contributing context through that
  context's existing `driver/gleam` facade (precedent:
  `collection/driver/gleam/collection_api.gleam`) — never their internals —
  and is the one place with enough context to check relationships between
  sections. `server/test/lint.gleam` gets a `Portability` category and one
  `allowed_cross_bc` pair per context it reads, added as each section lands.
- The document's shape is Portability's own type, encoded by Portability's
  own code — never Skir's generated JSON serialization of a contract type,
  and never a straight dump of a domain or DB row shape. This is what keeps
  a future Skir contract change (legal under ADR 0002) from being able to
  break a file already sitting on someone's disk: export files are exactly
  the external, out-of-band consumer ADR 0002's "no external RPC consumers"
  assumption excludes.
- The whole file is buffered, not streamed — real collection size is tens
  of thousands of rows, a few MB serialized.
- Both doors return the same filename, `tcg-card-collector-YYYY-MM-DD.json`,
  dated from the server clock (not the client's), so a REST client and the
  Skir client agree without either guessing the date.
- A JSON Schema for the document ships alongside the encoder
  (`docs/portability/export.schema.json`), so an editor can validate a hand
  edit as it's typed. Nothing yet keeps the schema and the encoder from
  drifting apart — see Consequences.

## Consequences

- #116 becomes: a `portability` context with one section (`collection`),
  not a CSV export inside Collection. #119's remaining sections are additive
  changes to the same document and the same version, not a new format.
- #117's import reads `format_version` first and rejects the whole file,
  naming the version it found, before parsing any section — the "never
  guess" acceptance criterion #133 already stated.
- Every new exported section costs one `allowed_cross_bc` pair from
  `Portability` to that context, and a driver-only read of that context's
  facade. This is more coupling than the rejected alternative, accepted for
  the one-place-to-check-cross-section-relationships and one-version
  properties above.
- The document shape is designed once, by Portability, rather than each
  context deciding independently how its own data should be externally
  representable. A context that wants its section to look different has to
  raise that with Portability's shape, not just change its own domain type.
- The schema file and the Gleam encoder are two hand-written descriptions of
  the same shape with nothing enforcing agreement between them yet. #133's
  planned frozen-fixture regression guard is the natural place to close this
  gap — noted there, not solved by this ADR.
- Support window (how many format versions back import must accept) and
  whether old versions get a step-by-step upgrade function or one parser
  per version stay open, tracked in #133.
