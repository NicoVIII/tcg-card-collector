-module(sqlite_store).
-export([exec/1, query/1, quote/1, reset_schema_cache/0]).

-define(SCHEMA_KEY, {sqlite_store, schema_ready}).
-define(DEFAULT_DB_FILE, "tcg-card-collector.db").

exec(Sql) ->
    ensure_schema(),
    _ = run(Sql),
    ok.

query(Sql) ->
    ensure_schema(),
    run(Sql).

quote(Value) when is_binary(Value) ->
    quote(binary_to_list(Value));
quote(Value) when is_list(Value) ->
    [$' | escape_sql(Value)] ++ [$'];
quote(Value) when is_integer(Value) ->
    integer_to_list(Value).

reset_schema_cache() ->
    persistent_term:erase(?SCHEMA_KEY),
    ok.

ensure_schema() ->
    case persistent_term:get(?SCHEMA_KEY, false) of
        true -> ok;
        false ->
            _ = run(schema_sql()),
            persistent_term:put(?SCHEMA_KEY, true),
            ok
    end.

schema_sql() ->
    "PRAGMA foreign_keys = ON;"
    "CREATE TABLE IF NOT EXISTS import_runs ("
    "  id TEXT PRIMARY KEY,"
    "  source_name TEXT NOT NULL,"
    "  source_checksum TEXT NOT NULL,"
    "  status TEXT NOT NULL CHECK (status IN ('pending', 'running', 'succeeded', 'failed')),
"
    "  started_at TEXT NOT NULL,"
    "  finished_at TEXT,"
    "  error_message TEXT,"
    "  imported_row_count INTEGER NOT NULL DEFAULT 0 CHECK (imported_row_count >= 0),"
    "  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,"
    "  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP"
    ");"
    "CREATE INDEX IF NOT EXISTS idx_import_runs_status ON import_runs(status);"
    "CREATE INDEX IF NOT EXISTS idx_import_runs_started_at ON import_runs(started_at DESC);"
    "CREATE TABLE IF NOT EXISTS collection_snapshot ("
    "  id TEXT PRIMARY KEY,"
    "  import_run_id TEXT NOT NULL REFERENCES import_runs(id) ON DELETE CASCADE,"
    "  row_number INTEGER NOT NULL CHECK (row_number > 0),"
    "  card_name TEXT NOT NULL,"
    "  set_code TEXT NOT NULL,"
    "  collector_number TEXT,"
    "  finish TEXT,"
    "  language TEXT,"
    "  quantity INTEGER NOT NULL CHECK (quantity > 0),"
    "  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,"
    "  UNIQUE(import_run_id, row_number)"
    ");"
    "CREATE INDEX IF NOT EXISTS idx_collection_snapshot_import_run_id ON collection_snapshot(import_run_id);"
    "CREATE INDEX IF NOT EXISTS idx_collection_snapshot_card_lookup ON collection_snapshot(card_name, set_code, collector_number);"
    "CREATE TABLE IF NOT EXISTS catalog_cards ("
    "  id TEXT PRIMARY KEY,"
    "  oracle_id TEXT NOT NULL,"
    "  name TEXT NOT NULL,"
    "  set_code TEXT NOT NULL,"
    "  collector_number TEXT NOT NULL,"
    "  rarity TEXT NOT NULL,"
    "  image_small_uri TEXT NOT NULL,"
    "  image_normal_uri TEXT NOT NULL,"
    "  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,"
    "  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP"
    ");"
    "CREATE INDEX IF NOT EXISTS idx_catalog_cards_name ON catalog_cards(name);"
    "CREATE INDEX IF NOT EXISTS idx_catalog_cards_set_code ON catalog_cards(set_code);"
    "CREATE INDEX IF NOT EXISTS idx_catalog_cards_oracle_id ON catalog_cards(oracle_id);"
    "CREATE TABLE IF NOT EXISTS catalog_sync_metadata ("
    "  id INTEGER PRIMARY KEY CHECK (id = 1),"
    "  last_probe_at TEXT,"
    "  last_upstream_updated_at TEXT,"
    "  last_refresh_status TEXT CHECK (last_refresh_status IS NULL OR last_refresh_status IN ('succeeded', 'failed', 'skipped')),
"
    "  last_error_message TEXT,"
    "  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP"
    ");"
    "CREATE TABLE IF NOT EXISTS inventory_rules ("
    "  id TEXT PRIMARY KEY,"
    "  location_name TEXT NOT NULL,"
    "  expression TEXT NOT NULL,"
    "  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,"
    "  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP"
    ");"
    "CREATE INDEX IF NOT EXISTS idx_inventory_rules_location_name ON inventory_rules(location_name);"
    "CREATE TABLE IF NOT EXISTS app_settings ("
    "  id INTEGER PRIMARY KEY CHECK (id = 1),"
    "  default_sort TEXT NOT NULL,"
    "  default_grouping TEXT NOT NULL,"
    "  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP"
    ");"
    "INSERT OR IGNORE INTO app_settings (id, default_sort, default_grouping) VALUES (1, 'card_name', 'location_name');".

run(Sql) ->
    DbFile = db_file(),
    Cmd =
        "sqlite3 -noheader -separator '\t' "
        ++ shell_quote(DbFile)
        ++ " "
        ++ shell_quote(Sql),
    os:cmd(Cmd).

db_file() ->
    case os:getenv("TCG_DB_FILE") of
        false -> ?DEFAULT_DB_FILE;
        Value -> Value
    end.

shell_quote(Value) when is_binary(Value) ->
    shell_quote(binary_to_list(Value));
shell_quote(Value) when is_list(Value) ->
    [$' | escape_shell(Value)] ++ [$'].

escape_shell([]) ->
    [];
escape_shell([$' | Rest]) ->
    "'\"'\"'" ++ escape_shell(Rest);
escape_shell([C | Rest]) ->
    [C | escape_shell(Rest)].

escape_sql([]) ->
    [];
escape_sql([$' | Rest]) ->
    "''" ++ escape_sql(Rest);
escape_sql([C | Rest]) ->
    [C | escape_sql(Rest)].
