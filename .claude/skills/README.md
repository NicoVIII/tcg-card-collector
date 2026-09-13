# Skills in this repo

Each `<name>/SKILL.md` here is a skill: an instruction sheet an agent loads
when a request matches its `description`, in the
[Agent Skills](https://agentskills.io/specification) format. Using one needs
nothing beyond an agent that reads skills.

| Skill | Summary | Suggested model | Maturity |
| --- | --- | --- | --- |
| [backlog](backlog/SKILL.md) | File issues, groom the backlog, plan release milestones and the next step | Opus | 🧪 Experimental |

One row per skill, added when the skill is. **Suggested model** is the model to
run it with — and the model its text is written for, so instructions are spelled
out for that one rather than for whatever stronger model happens to be running;
without a row, a skill is written for Sonnet. **Maturity** is
🚧 WIP → 🧪 Experimental → 🟢 Usable → 🛡️ Battle-tested, derived rather than
chosen: `skill-refiner <skill> maturity` rates the skill from its `HISTORY.md`
and names the edit this table needs.

`<name>/HISTORY.md` is not part of that format. It is an append-only log of the
skill's upkeep, one line per event:

    2026-08-03 · this-repo · 1233 words · fix big: <what the edit changed>

— the date, the repo the run happened in, the SKILL.md's word count at that
moment, and what happened: `created`, `retro clean|minor|major`,
`fix small|big`, `compacted`. It is what lets a skill be improved from evidence
rather than memory: which runs went badly, what each edit changed, and how far
the text has grown since anyone last shortened it deliberately.

So: never edit the log by hand and never rewrite a line already in it — the
word counts are a gap-free series and the line shape is parsed, so both its
readers break on a hand-written entry. Commit each entry with the skill edit it
describes, or the log and the SKILL.md disagree about which text a run judged.

The tooling that appends those lines — and the workflow around it: capture a
skill, review it against the run that just used it, compact it when it has
bloated — lives in <https://github.com/NicoVIII/claude-config>, a `~/.claude`
config to clone or fork. Without it this log stays readable by anyone; it just
has nothing writing to or rating it.

This file came from there, seeded on the first entry logged in this repo, and
is never overwritten — edit it to suit the project.
