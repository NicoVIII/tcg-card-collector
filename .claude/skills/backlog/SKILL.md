---
name: backlog
description: >
  Tri-mode work management for this repo's GitHub issues and milestones — filing
  issues well, grooming the backlog, and planning releases / picking the next
  step. Use when asked "what should I work on next", to groom or triage the
  backlog, to plan or scope a release milestone, or when turning review findings
  into issues. GitHub Projects are out of scope until a concrete need appears.
---

You are managing this repo's work in one of three modes. Pick by what was asked:

- **File** — turn a finding or idea into a well-formed issue, or decide it should
  not become one.
- **Groom** — hygiene pass over the open issues: labels, staleness, duplicates,
  quality.
- **Plan** — propose or maintain the milestone structure and recommend the best
  next step.

The surface is GitHub issues + milestones via `gh`. GitHub Projects are
deliberately not used: they need an extra auth scope in every environment an
agent runs in, and they add a second status surface that can drift from issue
state. Revisit only when a concrete need appears that milestones cannot serve —
do not adopt them by accretion.

## Milestones are releases

**A milestone is a version with a headline.** Milestones are named `v0.1`,
`v0.2`, … and each carries a one-line headline outcome in its description —
what state of the product this release delivers. The version number orders;
the headline scopes. An issue belongs to a milestone iff it serves the
headline, and arguing an issue in or out means arguing against the headline,
stated explicitly.

**Horizon: current release plus at most the next.** Only those get milestones.
Everything else stays unassigned, triaged by labels — no "someday" milestone,
no pre-sorting the far backlog into future versions. Assigning v0.5 content
today is planning theater that grooming would spend forever re-shuffling.

**Closing and rolling.** When a milestone's issues are done, close it and
propose the next version's headline. Tagging, changelog, and publishing belong
to the release process — this skill closes and rolls milestones, it never
invents release mechanics.

## The next-step ladder (plan)

Within the current release milestone: **bugs → foundation issues that unblock
other milestone work → the rest**, dependency-aware — an issue that gates
others outranks its label tier. The recommendation is one pick (a runner-up at
most), with the argument: why this, why now, what it unblocks. Never an
unranked list of options.

Stepping outside the current milestone requires a stated argument (e.g. a
data-loss bug just landed). Silently recommending off-milestone work is the
failure mode this ladder exists to prevent.

## Filing rules (file)

**Triage before filing.** Trivial fixes get fixed, not filed. Ideas outside
[docs/vision.md](../../../docs/vision.md) scope get named as out of scope, not
parked as issues. Small nits from a review pass bundle into one sweep issue,
not one issue each.

**Exactly one taxonomy label.** `bug` = observed wrong behaviour. `foundation`
= enabler work — DX, code quality, things that unblock or de-risk other work.
`enhancement` = new capability. Every issue carries exactly one of the three.

**Cold-startable body.** A future agent must be able to start work from the
issue alone: bugs get repro plus expected/actual, features get the acceptance
shape, and the title is specific enough to triage from the list view.

**Milestone at filing: default none.** Assign only when the issue serves the
current or next release's headline.

## Groom checks (groom)

- **Label discipline** — exactly one of bug/foundation/enhancement; flag
  missing or conflicting.
- **Staleness vs reality** — check open issues against current code and ADRs;
  some are already fixed or superseded. Propose closure with the reason.
- **Duplicates and overlap** — issues covering the same ground get a proposed
  merge or a closure with cross-reference.
- **Issue quality** — hold existing issues to the same cold-startable standard
  as filing; flag ones a fresh agent could not start from.

## Authority

Reading is free. Every write — creating milestones, assigning issues,
relabeling, editing bodies, closing — is assembled into **one reviewable
changeset and applied after a single approval**. Closures are always listed
prominently in that changeset, never buried in the batch. No silent writes to
GitHub state, ever.

## How to report

**Groom mode** — the proposed changeset grouped by check, closures first, each
item with its one-line reason.

**Plan mode** — current milestone state (headline, open/closed counts), the
single recommended next step with its argument, and any milestone-structure
changes as a changeset per the authority rule.
