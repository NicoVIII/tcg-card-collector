# container

Runtime assets for the Docker image.

## start.sh

Entrypoint script. Runs database migrations with dbmate before handing off to
the Gleam erlang-shipment `entrypoint.sh`. The app assumes the schema exists
and does not migrate itself.

## Image environment variables

| Variable      | Default                            | Description                        |
|---------------|------------------------------------|------------------------------------|
| `PORT`        | `8080`                             | HTTP listen port                   |
| `TCG_DB_FILE` | `/data/tcg-card-collector.db`      | Path to the SQLite database file   |
| `STATIC_DIR`  | `/app/static`                      | Path to the built frontend assets  |

## Data volume

Mount a writable volume at `/data`. The database lives there. Back up by
copying that single file.

```
docker run -d -p 8080:8080 -v tcg-data:/data ghcr.io/nicoviii/tcg-card-collector:latest
```
