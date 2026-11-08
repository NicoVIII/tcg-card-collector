-- migrate:up

-- A placed-ledger location is no longer bare text (#122): a cascade location
-- (rule target or bulk) is still identified by its rendered name, but a
-- managed location (a deck) is identified by its id, so the two can share a
-- display name without their rows merging. `location` holds the name for
-- 'cascade' and the managed location's id for 'managed'. No FK backs the
-- 'managed' rows: the column is polymorphic, and the app's connections don't
-- enable foreign_keys anyway — deleting a managed location removes its rows
-- in the same transaction instead. Every existing row predates managed
-- locations and backfills as 'cascade'. No row is dropped.
CREATE TABLE placed_cards_location_kind (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  finish TEXT NOT NULL CHECK (finish IN ('nonfoil', 'foil', 'etched')),
  language TEXT NOT NULL CHECK (language IN (
    'en', 'es', 'fr', 'de', 'it', 'pt', 'ja', 'ko', 'ru', 'zhs', 'zht', 'he',
    'la', 'grc', 'ar', 'sa', 'ph', 'qya'
  )),
  location_kind TEXT NOT NULL CHECK (location_kind IN ('cascade', 'managed')),
  location TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number, finish, language, location_kind, location)
) STRICT;

INSERT INTO placed_cards_location_kind (set_code, collector_number, finish, language, location_kind, location, quantity)
  SELECT set_code, collector_number, finish, language, 'cascade', location, quantity FROM placed_cards;

DROP TABLE placed_cards;
ALTER TABLE placed_cards_location_kind RENAME TO placed_cards;

-- migrate:down

-- Schema-faithful, not data-faithful: 'managed' rows have no text location
-- the old schema could hold, so they are dropped.
CREATE TABLE placed_cards_pre_location_kind (
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

INSERT INTO placed_cards_pre_location_kind (set_code, collector_number, finish, language, location, quantity)
  SELECT set_code, collector_number, finish, language, location, quantity
  FROM placed_cards
  WHERE location_kind = 'cascade';

DROP TABLE placed_cards;
ALTER TABLE placed_cards_pre_location_kind RENAME TO placed_cards;
