# container

Runtime assets for the Docker image.

## start.sh

Entrypoint script. Runs database migrations with dbmate before handing off to
the Gleam erlang-shipment `entrypoint.sh`. The app assumes the schema exists
and does not migrate itself.

## Image environment variables

Operator-tunable:

| Variable      | Default                            | Description                        |
|---------------|------------------------------------|------------------------------------|
| `PORT`        | `8080`                             | HTTP listen port                   |
| `TCG_DB_FILE` | `/data/tcg-card-collector.db`      | Path to the SQLite database file   |
| `STATIC_DIR`  | `/app/static`                      | Path to the built frontend assets  |

Build identity, baked in at image build time (`ARG APP_CHANNEL` / `ARG APP_COMMIT` in the `Dockerfile`) — not meant to be overridden at `docker run`:

| Variable           | Default | Description                                           |
|--------------------|---------|--------------------------------------------------------|
| `TCG_APP_CHANNEL`  | `dev`   | `release` for a `v*`-tag build, `dev` otherwise         |
| `TCG_APP_COMMIT`   | `local` | Short git SHA the image was built from                 |

Together with `server/gleam.toml`'s version, these compose the string shown in the UI footer and served at `/api/version` (see [Versioning & Releases](../docs/dev/development.md#versioning--releases)).

## Data volume

Mount a writable volume at `/data`. The database lives there.

Running the image, choosing a tag, upgrading, and backup/restore are documented
in the root [README](../README.md#self-hosting).
