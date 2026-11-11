-- migrate:up

-- Target set codes used to be stored as typed ("GRN", " grn "), so they never
-- matched the catalog's or the collection's canonical lowercase code and read
-- 0 owned forever (#175). Rows are canonicalised forward rather than dropped:
-- the table is user-authored. Spellings that collapse onto one code keep the
-- earliest created_at; a code blank after trimming tracked nothing and goes.
-- The CHECK keeps any writer from storing a non-canonical code again. SQLite's
-- lower() folds ASCII only, which covers every real set code.
CREATE TABLE target_sets_canonical (
  set_code TEXT PRIMARY KEY
    CHECK (set_code <> '' AND set_code = lower(trim(set_code, ' ' || char(9) || char(10) || char(13)))),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
) STRICT;
INSERT INTO target_sets_canonical (set_code, created_at)
  SELECT lower(trim(set_code, ' ' || char(9) || char(10) || char(13))) AS canonical, min(created_at)
  FROM target_sets
  WHERE canonical <> ''
  GROUP BY canonical;
DROP TABLE target_sets;
ALTER TABLE target_sets_canonical RENAME TO target_sets;

-- migrate:down

CREATE TABLE target_sets_unchecked (
  set_code TEXT PRIMARY KEY,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
) STRICT;
INSERT INTO target_sets_unchecked (set_code, created_at)
  SELECT set_code, created_at FROM target_sets;
DROP TABLE target_sets;
ALTER TABLE target_sets_unchecked RENAME TO target_sets;
