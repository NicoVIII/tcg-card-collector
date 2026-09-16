-- migrate:up

-- CopyKey (ADR 0010): a placement ticks off a specific kind of copy, not just
-- a printing — a location holding several kinds of copy of one printing needs
-- a tick that names which kind. Rebuilt for the same reason as migration
-- 0016; every existing row predates finish/language tracking and is
-- backfilled as nonfoil/en. No row is dropped.
CREATE TABLE placed_cards_copy_key (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  finish TEXT NOT NULL CHECK (finish IN ('nonfoil', 'foil', 'etched')),
  language TEXT NOT NULL CHECK (language IN (
    'en', 'es', 'fr', 'de', 'it', 'pt', 'ja', 'ko', 'ru', 'zhs', 'zht', 'he',
    'la', 'grc', 'ar', 'sa', 'ph', 'qya'
  )),
  location TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number, finish, language, location)
) STRICT;

INSERT INTO placed_cards_copy_key (set_code, collector_number, finish, language, location, quantity)
  SELECT set_code, collector_number, 'nonfoil', 'en', location, quantity FROM placed_cards;

DROP TABLE placed_cards;
ALTER TABLE placed_cards_copy_key RENAME TO placed_cards;

-- migrate:down

-- Schema-faithful, not data-faithful: rows are re-summed per (set_code,
-- collector_number, location), so the finish/language split above is lost.
CREATE TABLE placed_cards_pre_copy_key (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  location TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number, location)
) STRICT;

INSERT INTO placed_cards_pre_copy_key (set_code, collector_number, location, quantity)
  SELECT set_code, collector_number, location, SUM(quantity)
  FROM placed_cards
  GROUP BY set_code, collector_number, location;

DROP TABLE placed_cards;
ALTER TABLE placed_cards_pre_copy_key RENAME TO placed_cards;
