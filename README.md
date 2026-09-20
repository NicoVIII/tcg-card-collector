# tcg-card-collector

[![Last commit](https://img.shields.io/github/last-commit/NicoVIII/tcg-card-collector?style=flat-square)](https://github.com/NicoVIII/tcg-card-collector/commits/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)

A self-hosted service for managing a Magic: The Gathering card collection and planning its physical organization. Card metadata is synced from Scryfall, the owned collection is imported from CSV exports, and user-defined location rules turn the collection into grouped and sorted projections — a plan for sorting real cards into real storage.

See [docs/vision.md](docs/vision.md) for why the project exists, where it is heading, and what it deliberately will not do.

## What works today

- Catalog sync from Scryfall
- CSV collection import replacing the live collection
- Adding, removing, or adjusting owned quantities, correcting the placed ledger to match
- Location rules and inventory projections for physical sorting
- A re-sort worklist flags placed copies a rule change left behind, and re-points a renamed location's records without treating it as a physical move
- All of it available over Skir RPC and REST

## Status

The MVP vertical slice works end-to-end. Docker images are published to [GHCR](https://ghcr.io/nicoviii/tcg-card-collector) on every push to `main` and on `v*` version tags. The deployment model is a single user on a trusted network: the app has **no authentication — do not expose it to untrusted networks**.

## Self-hosting

```
docker run -d -p 8080:8080 -v tcg-data:/data ghcr.io/nicoviii/tcg-card-collector:0.1
```

- SQLite database is stored at `/data/tcg-card-collector.db` (override with `TCG_DB_FILE`)
- Migrations run automatically at container start
- Bind mounts must be writable by the container user (`webapp`, uid 1000)
- **No authentication — do not expose to untrusted networks**
- The running version shows in the page footer, and at `curl http://localhost:8080/api/version`

### Image tags

| Tag       | Tracks                                     |
|-----------|---------------------------------------------|
| `X.Y.Z`   | One exact release. Never moves.              |
| `X.Y`     | Patch fixes for that minor version (the example above). |
| `latest`  | The newest release. Moves across minor and major versions, including breaking changes. |
| `main`    | Every push to `main`. Unreleased, no data-preservation promise. |

Pin `X.Y` or `X.Y.Z` for a self-hosted instance; don't run `latest` unattended.

### Upgrading

1. [Back up](#backup--restore) the database.
2. `docker pull` the new tag.
3. Recreate the container (`docker stop` + `docker rm` the old one, `docker run` with the new tag and the same volume). Migrations run automatically on start.

There is no supported downgrade: the `down` side of a migration is a development tool and does not restore data it dropped. Going back to an older version means restoring the backup and running the old tag.

### Backup & restore

The database is a single SQLite file; no other tooling is required.

**Backup while stopped** (simplest):

```sh
docker stop <container>
docker cp <container>:/data/tcg-card-collector.db ./backup.db
docker start <container>
```

**Backup without downtime**, using the `sqlite3` CLI bundled in the image:

```sh
docker exec <container> sqlite3 /data/tcg-card-collector.db ".backup '/data/backup.db'"
docker cp <container>:/data/backup.db ./backup.db
```

**Restore**: stop the container, copy the backup file into the volume as `tcg-card-collector.db` (remove any leftover `-wal`/`-shm` files alongside it), then start the container.

### Data preservation

From v0.1.0 on, an upgrade never loses collection or inventory data. A release that can't guarantee this says so explicitly in its release notes.

The Scryfall catalog is external data and isn't covered by this promise — a migration may drop it, provided a re-sync restores it.

## Architecture

Gleam backend (Erlang target) and SolidJS/TypeScript frontend, connected by a [Skir](https://github.com/gepheum/skir) contract — contract-first RPC with code generation for both sides. The backend follows hexagonal architecture with DDD bounded contexts, and the boundaries are lint-enforced. This rigor is deliberate: the project doubles as an architecture playground, not just a tool.

## Development

Setup, commands, and quality gates are documented in the [development guide](docs/dev/development.md).
