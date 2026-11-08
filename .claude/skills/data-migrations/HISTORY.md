# Skill History

2026-11-08 · tcg-card-collector · 887 words · retro minor: user-authored table list went stale (missed #122 managed_locations tables); migration-test guidance to read through the owning DAO broke the frozen 0017 test on 0021 — deferred: app connections never enable foreign_keys, so declared FKs/ON DELETE CASCADE never fire (re-derived by grep)
2026-11-08 · tcg-card-collector · 904 words · fix big: user-authored tables defined as whatever Portability exports instead of a list; migration tests read with their own query, never the owning DAO (README rule + 0016/0021 tests migrated)
