-- migrate:up

-- Inventory planning owns where cards were physically placed. Unplaced is always
-- derived (collection minus placed per key), never stored, so nothing can be lost.
CREATE TABLE placed_cards (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  location TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number, location)
);

DROP TABLE unplaced_cards;

-- migrate:down

CREATE TABLE unplaced_cards (
  set_code TEXT NOT NULL,
  collector_number TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (set_code, collector_number)
);

DROP TABLE placed_cards;
