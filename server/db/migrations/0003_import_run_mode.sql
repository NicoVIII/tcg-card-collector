-- migrate:up

ALTER TABLE import_runs ADD COLUMN mode TEXT NOT NULL DEFAULT 'full' CHECK (mode IN ('full', 'delta'));

-- migrate:down

ALTER TABLE import_runs DROP COLUMN mode;
