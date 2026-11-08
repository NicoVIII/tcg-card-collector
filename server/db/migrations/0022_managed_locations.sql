-- migrate:up

-- Managed locations (#122, ADR 0022): a named location whose contents are an
-- explicit membership list instead of a rule predicate. `deck` is the only
-- kind so far. Names are unique among managed locations only — a deck may
-- share its name with a rule target, since the two live in different
-- LocationRef namespaces.
CREATE TABLE managed_locations (
  id TEXT PRIMARY KEY CHECK (id <> ''),
  name TEXT NOT NULL UNIQUE CHECK (name <> ''),
  kind TEXT NOT NULL CHECK (kind IN ('deck'))
) STRICT;

-- Membership is intent, not fact: a row says the location should hold these
-- copies, whether or not the collection currently owns that many (a
-- shortfall is derived at projection time, never pruned here). The REFERENCES
-- documents ownership; the app's connections don't enable foreign_keys, so
-- deleting a managed location removes its members explicitly.
CREATE TABLE managed_location_members (
  managed_location_id TEXT NOT NULL REFERENCES managed_locations(id),
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  finish TEXT NOT NULL CHECK (finish IN ('nonfoil', 'foil', 'etched')),
  language TEXT NOT NULL CHECK (language IN (
    'en', 'es', 'fr', 'de', 'it', 'pt', 'ja', 'ko', 'ru', 'zhs', 'zht', 'he',
    'la', 'grc', 'ar', 'sa', 'ph', 'qya'
  )),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (managed_location_id, set_code, collector_number, finish, language)
) STRICT;

-- migrate:down

DROP TABLE managed_location_members;
DROP TABLE managed_locations;
