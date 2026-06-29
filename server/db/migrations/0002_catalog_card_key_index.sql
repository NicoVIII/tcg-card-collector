-- migrate:up

CREATE INDEX IF NOT EXISTS idx_catalog_cards_key ON catalog_cards(set_code, collector_number);

-- migrate:down

DROP INDEX IF EXISTS idx_catalog_cards_key;
