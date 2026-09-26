# 0020 — Export format compatibility window and per-version decoders

- Status: accepted
- Date: 2026-09-26

## Context

ADR 0019 gave every export a top-level `format_version` and made import
reject an unknown one as a whole-file error, naming the version it found.
That answers "does import notice a version it doesn't handle" but not the
three questions #133 raised and ADR 0019 explicitly left open: how far back
import must actually reach, how an old version gets read once a newer one
exists, and what proves an old file still imports losslessly once the
encoder has moved on. Nothing enforced any of this yet — there was no second
format version to test against, and nothing checked
`docs/portability/export.schema.json` against the Gleam encoder it's meant
to describe.

## Considered options

- **Support window**
  - *Current major version plus the previous one* — won. A release imports
    every `format_version` written by an app release of its own major
    version or the one before. Concretely: every 0.x release reads every
    format written by any 0.x release; the first 1.x release still reads
    every 0.x format, and drops that support only in a later major. This
    matches how the rest of the project already scopes compatibility
    promises to majors (`docs/vision.md`), and gives a self-hoster a
    predictable answer — "upgrade at least once every major cycle before a
    file goes stale" — without promising to carry every format forever.
  - *Every format version since v0.2.0, forever* — lost. This is what the
    v0.2.0 milestone description originally said ("from v0.2.0 on"), but it
    commits every future release to carrying every decoder ever written,
    with no way to ever delete one. Nothing in the project's other
    compatibility promises (the DB migration chain, the Skir contract) makes
    an unbounded promise like this; the milestone description and
    `docs/vision.md` are reworded to match this ADR instead.
  - *A fixed number of releases back* — lost. Releases don't happen on a
    fixed cadence, so "last N releases" doesn't translate into a promise a
    self-hoster can reason about ("is my 8-month-old export still good?");
    tying it to major versions does.

- **Reading an old format version**
  - *One decoder per format version, each producing the current
    `ImportDocument`* — won. `export_file.parse` dispatches on
    `format_version` to `decode_v1`, `decode_v2`, and so on, sharing field
    decoders where the shape agrees. A released decoder is frozen the same
    way a shipped DB migration is: it may not change once a version exists
    that real files were written with. Adding format_version N+1 means
    adding `decode_vN+1` and a dispatch arm, not touching `decode_vN`.
  - *Step-by-step upgrade, migration-style* — lost. A DB migration rewrites
    rows in place; an export format upgrade would need to rewrite a decoded
    JSON tree before the current decoder runs. `gleam_json` can only
    *decode* into a `Dynamic`/typed value or *encode* from one — it has no
    way to build or edit a `Dynamic` tree, so every upgrade step would need
    to fully decode, transform, and re-serialize to a string, then re-parse
    it, for every step between the file's version and the current one. A
    per-version decoder needs none of that: it decodes directly into the
    current shape in one pass.

- **Regression guard**
  - *A frozen fixture per format version, imported by the current build and
    checked for exact resulting state* (#123's `with_seeded_upgrade`
    precedent) — won. `server/test/portability/fixtures/format_v<N>.json`,
    one file per version, never edited after it lands; a new format version
    adds a fixture rather than changing one. The current version's fixture
    additionally round-trips byte-for-byte through export, which is what
    ties the encoder to the fixture in the first place.
  - *Property-based fuzzing of the decoder* — lost, not rejected: this
    catches decoder crashes on malformed input, which is a different concern
    (already covered by `RejectedEntry`/`DocumentError` handling) from
    proving one specific, real file keeps importing losslessly release over
    release.

- **Schema-vs-encoder drift**
  - *A pinned `ajv-cli` validation of every frozen fixture against
    `export.schema.json`, run in the root `check` group* — won. Same
    "pinned exactly, run via bunx/npx" pattern the `skir` recipes already
    use, and it needs the fixtures above to mean anything: validating a
    hand-typed example against the schema proves nothing about what the
    encoder actually emits, whereas validating a byte-identical fixture
    does.
  - *A generated schema, kept in sync with the encoder by construction* —
    lost, not rejected: revisiting this is reasonable once there's a second
    format version to generalize the schema across, but it's a bigger change
    than #133's scope and isn't needed to close the gap ADR 0019 flagged.

## Decision

- A release imports every `format_version` written by any release of its own
  major version or the previous one. Dropping an older format is only a
  major-release action, and it ships with a `### Upgrading` CHANGELOG note
  telling anyone still on that format to re-export on their current version
  first. `docs/dev/development.md` § Versioning & Releases carries the bump
  checklist and the drop rule; this ADR carries the rationale.
- `export_file.parse` (or its successor once there's more than one version)
  dispatches on `format_version` to one decoder per version, each producing
  the current `ImportDocument`. A shipped decoder is frozen like a shipped
  migration — a shape bug in `decode_v1` found after release is fixed
  forward in a new version, never by editing `decode_v1`.
- Every format version ships with one frozen fixture under
  `server/test/portability/fixtures/format_v<N>.json`
  (`server/test/AGENTS.md`), imported by
  `format_fixtures_test.gleam` and checked for exact resulting state; the
  current version's fixture is also checked to re-export byte-identically.
- The root `just portability-schema-check` validates every fixture in that
  directory against `docs/portability/export.schema.json` with a pinned
  `ajv-cli`, and runs as part of `just check`.

## Consequences

- Bumping `format_version` costs: a new `decode_vN` function, a new frozen
  fixture, repointing the "current fixture" constant the byte-identical test
  reads, a schema update if the new version's shape isn't covered by the
  existing one, and a CHANGELOG line. This is deliberately more ceremony than
  a silent shape change would need, in exchange for the same guarantee
  #123's migration fixtures give the database.
  Older decoders keep working, entirely untouched, until a major release
  drops them.
- The support window is now finite and stated, so a self-hoster can be told
  plainly when a file will stop importing, instead of the open-ended
  "supported forever" the v0.2.0 milestone description originally implied.
  `docs/vision.md` and the v0.2.0 milestone description are reworded to
  match.
- The schema check only validates the fixtures against the schema; it
  doesn't derive one from the other. A second format version will need the
  schema restructured (likely a `oneOf` keyed on `format_version`) — left for
  when that version exists, not solved speculatively here.
