ARG GLEAM_VERSION=v1.17.0
ARG ERLANG_VERSION=27
ARG SKIR_VERSION=1.2.19
# SKIR_VERSION is also pinned in the root justfile (skir_version); keep them in sync.
ARG DBMATE_VERSION=v2.33.0

# ── Stage 1: generate skir contract code ─────────────────────────────────────

FROM oven/bun:1-alpine AS skir-gen

ARG SKIR_VERSION

WORKDIR /skir

COPY skir.yml skir-snapshot.json ./
COPY skir-src/ ./skir-src/

RUN bunx skir@${SKIR_VERSION} gen

# ── Stage 2: build the frontend ───────────────────────────────────────────────

FROM oven/bun:1-alpine AS frontend-builder

WORKDIR /app

# Install dependencies before copying sources for layer caching.
COPY client-web/package.json client-web/bun.lock ./
RUN bun install --frozen-lockfile

COPY client-web/ ./
COPY --from=skir-gen /skir/client-web/src/data/skirout/ ./src/data/skirout/

RUN bun run build

# ── Stage 3: gleam binary ─────────────────────────────────────────────────────

FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-scratch AS gleam

# ── Stage 4: build the Gleam server ──────────────────────────────────────────

FROM erlang:${ERLANG_VERSION}-alpine AS server-builder

ARG SKIR_VERSION

# sqlight requires a C compiler for its NIF.
RUN apk add --no-cache build-base

COPY --from=gleam /bin/gleam /usr/local/bin/gleam

WORKDIR /app

COPY server/ ./

RUN gleam deps download

COPY --from=skir-gen \
  /skir/server/src/shared/driver/skir/skirout/ \
  ./src/shared/driver/skir/skirout/

RUN gleam export erlang-shipment

# ── Stage 5: download dbmate ──────────────────────────────────────────────────

FROM alpine AS dbmate-downloader

ARG DBMATE_VERSION
ARG TARGETARCH

RUN wget -qO /dbmate \
  "https://github.com/amacneil/dbmate/releases/download/${DBMATE_VERSION}/dbmate-linux-${TARGETARCH}" \
  && chmod +x /dbmate

# ── Stage 6: runtime image ────────────────────────────────────────────────────

FROM erlang:${ERLANG_VERSION}-alpine

RUN apk add --no-cache curl jq sqlite && adduser -D -H -h /app webapp

COPY --from=server-builder --chown=webapp /app/build/erlang-shipment/ /app/
COPY --from=frontend-builder --chown=webapp /app/dist/ /app/static/
COPY --chown=webapp server/db/migrations/ /app/db/migrations/
COPY --from=dbmate-downloader /dbmate /usr/local/bin/dbmate
COPY --chown=webapp container/start.sh /app/start.sh

RUN chmod +x /app/start.sh

ENV STATIC_DIR=/app/static \
    TCG_DB_FILE=/data/tcg-card-collector.db \
    PORT=8080

RUN mkdir /data && chown webapp:webapp /data

VOLUME /data

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --spider -q http://127.0.0.1:8080/ || exit 1

USER webapp

ENTRYPOINT ["/app/start.sh"]
CMD ["run"]
