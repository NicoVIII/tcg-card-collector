-- migrate:up

-- Scryfall's raw layout value ("token", "double_faced_token", "normal", ...),
-- stored as a fact per ADR 0008 — planning decides what it means (#135).
-- Nullable because the bulk dump always ships this field, but the column
-- itself is absent until the next full reload; NULL is that gap, distinct
-- from any real layout string.
ALTER TABLE catalog_cards ADD COLUMN layout TEXT CHECK (layout IS NULL OR layout <> '');

-- Force the next manual refresh to do a full reload; see
-- server/src/card_catalog/AGENTS.md for why clearing the whole record (not
-- nulling last_upstream_updated_at) is the only way this actually works.
DELETE FROM catalog_sync_metadata;

-- migrate:down

ALTER TABLE catalog_cards DROP COLUMN layout;
