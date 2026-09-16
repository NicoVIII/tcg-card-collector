-- migrate:up

-- CopyKey (ADR 0010): a kind of owned copy is (set_code, collector_number,
-- finish, language), not just the printing. SQLite can't ALTER a CHECK
-- constraint or a PRIMARY KEY onto an existing table, so collection is
-- rebuilt. Every existing row predates finish/language tracking and is
-- backfilled as nonfoil/en, per ADR 0010's decision that there is no unknown
-- case — a re-import corrects the values. No row is dropped.
CREATE TABLE collection_copy_key (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  finish TEXT NOT NULL CHECK (finish IN ('nonfoil', 'foil', 'etched')),
  language TEXT NOT NULL CHECK (language IN (
    'en', 'es', 'fr', 'de', 'it', 'pt', 'ja', 'ko', 'ru', 'zhs', 'zht', 'he',
    'la', 'grc', 'ar', 'sa', 'ph', 'qya'
  )),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number, finish, language)
) STRICT;

INSERT INTO collection_copy_key (set_code, collector_number, finish, language, quantity)
  SELECT set_code, collector_number, 'nonfoil', 'en', quantity FROM collection;

DROP TABLE collection;
ALTER TABLE collection_copy_key RENAME TO collection;

-- migrate:down

-- Schema-faithful, not data-faithful: rows are re-summed per (set_code,
-- collector_number), so the finish/language split introduced above is lost.
-- Downs are a dev-loop tool, not the production rollback story.
CREATE TABLE collection_pre_copy_key (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number)
) STRICT;

INSERT INTO collection_pre_copy_key (set_code, collector_number, quantity)
  SELECT set_code, collector_number, SUM(quantity)
  FROM collection
  GROUP BY set_code, collector_number;

DROP TABLE collection;
ALTER TABLE collection_pre_copy_key RENAME TO collection;
