# Skills in this repo

Each `<name>/SKILL.md` here is a skill: an instruction sheet an agent loads
when a request matches its `description`, in the
[Agent Skills](https://agentskills.io/specification) format. Using one needs
nothing beyond an agent that reads skills.

| Skill | Summary | Suggested model | Maturity |
| --- | --- | --- | --- |
| [architecture](architecture/SKILL.md) | Design and review structure: functional core / imperative shell, DDD, ports and adapters, CQRS | Opus | 🚧 WIP |
| [contract-design](contract-design/SKILL.md) | Shape Skir methods and wire types, and keep the REST surface honest | Opus | 🚧 WIP |
| [data-migrations](data-migrations/SKILL.md) | Design and review SQLite schema, DB invariants, and dbmate migrations | Opus | 🚧 WIP |
| [documentation](documentation/SKILL.md) | Route knowledge to the right doc tier, write ADRs, hunt doc–code drift | Opus | 🚧 WIP |
| [domain-design](domain-design/SKILL.md) | Place concepts in bounded contexts and keep MTG semantics honest | Opus | 🚧 WIP |
| [qa](qa/SKILL.md) | Judge test quality and verify the running app against real behaviour | Opus | 🚧 WIP |
| [ux-design](ux-design/SKILL.md) | Design and review flows, density, and feedback for the physical sorting task | Opus | 🚧 WIP |

**Suggested model** is the model to run the skill with. **Maturity** is
🚧 WIP → 🧪 Experimental → 🟢 Usable → 🛡️ Battle-tested, rated from the skill's
`HISTORY.md` rather than claimed.

That log is not part of the skill format. It records the skill's upkeep, one
line per event:

    2026-08-03 · this-repo · 1233 words · fix big: <what the edit changed>

— the date, the repo the run happened in, the SKILL.md's word count at that
moment, and what happened (`created`, `retro clean|minor|major`,
`fix small|big`, `compacted`). Read together, the lines say which runs went
badly, what each edit changed, and how far the text has grown since anyone last
shortened it — so a skill can be improved from evidence rather than memory.
They are appended by tooling and parsed by it: a line edited by hand breaks the
word-count series the rating reads.

That tooling lives in <https://github.com/NicoVIII/claude-config>, a `~/.claude`
config to clone or fork. Without it the skills here still run and the logs still
read; nothing appends to or rates them.

This file was seeded from there with the first log entry, and is never
overwritten — edit it to suit the project.
