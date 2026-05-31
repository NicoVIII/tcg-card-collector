-module(card_catalog_store).
-export([refresh/0, upsert/3, list/0, clear/0]).

-define(BULK_METADATA_URL, "https://api.scryfall.com/bulk-data/default_cards").
-define(DEFAULT_DB_FILE, "tcg-card-collector.db").

refresh() ->
    case should_probe() of
        false -> {ok, nil};
        true ->
            case fetch_bulk_metadata() of
                {error, Reason} ->
                    mark_probe_failed(Reason),
                    {error, unicode:characters_to_binary(Reason)};
                {ok, UpdatedAt, DownloadUri} ->
                    case current_upstream_updated_at() of
                        UpdatedAt ->
                            mark_probe_skipped(UpdatedAt),
                            {ok, nil};
                        _ ->
                            case import_cards(DownloadUri) of
                                ok ->
                                    mark_probe_succeeded(UpdatedAt),
                                    {ok, nil};
                                {error, Reason} ->
                                    mark_probe_failed(Reason),
                                    {
                                        error,
                                        unicode:characters_to_binary(
                                            "catalog refresh failed: " ++ Reason
                                        )
                                    }
                            end
                    end
            end
    end.

upsert(Id, Name, SetCode) ->
    Sql =
        "INSERT INTO catalog_cards ("
        "  id, oracle_id, name, set_code, collector_number, rarity, image_small_uri, image_normal_uri"
        ") VALUES ("
        ++ sqlite_store:quote(Id)
        ++ ", "
        ++ sqlite_store:quote(Id)
        ++ ", "
        ++ sqlite_store:quote(Name)
        ++ ", "
        ++ sqlite_store:quote(SetCode)
        ++ ", ''"
        ++ ", 'unknown'"
        ++ ", ''"
        ++ ", ''"
        ++ ") "
        "ON CONFLICT(id) DO UPDATE SET "
        "  oracle_id = excluded.oracle_id,"
        "  name = excluded.name,"
        "  set_code = excluded.set_code,"
        "  updated_at = CURRENT_TIMESTAMP;",
    ok = sqlite_store:exec(Sql),
    nil.

list() ->
    Output =
        sqlite_store:query(
            "SELECT id, name, set_code "
            "FROM catalog_cards "
            "ORDER BY name ASC, set_code ASC, collector_number ASC, id ASC;"
        ),
    parse_rows(Output).

clear() ->
    ok = sqlite_store:exec("DELETE FROM catalog_cards;"),
    ok = sqlite_store:exec("DELETE FROM catalog_sync_metadata;"),
    nil.

should_probe() ->
    Output =
        sqlite_store:query(
            "SELECT last_probe_at "
            "FROM catalog_sync_metadata "
            "WHERE id = 1 AND last_probe_at >= datetime('now', '-1 day') "
            "LIMIT 1;"
        ),
    string:trim(Output) =:= [].

current_upstream_updated_at() ->
    Output =
        sqlite_store:query(
            "SELECT COALESCE(last_upstream_updated_at, '') "
            "FROM catalog_sync_metadata "
            "WHERE id = 1 LIMIT 1;"
        ),
    string:trim(Output).

fetch_bulk_metadata() ->
    Script =
        "set -e; "
        "curl -fsSL "
        ++ shell_quote(?BULK_METADATA_URL)
        ++ " | jq -r '[.updated_at, .download_uri] | @tsv'",
    case run_shell(Script) of
        {error, Output} -> {error, simplify_error(Output)};
        {ok, Output} ->
            case string:split(string:trim(Output), "\t", all) of
                [UpdatedAt, DownloadUri] when UpdatedAt =/= [], DownloadUri =/= [] ->
                    {ok, UpdatedAt, DownloadUri};
                _ -> {error, "invalid metadata response from scryfall"}
            end
    end.

import_cards(DownloadUri) ->
    ok = sqlite_store:exec("SELECT 1;"),
    Script =
        "set -e; "
        "tmp=$(mktemp); "
        "trap 'rm -f \"$tmp\"' EXIT; "
        "curl -fsSL "
        ++ shell_quote(DownloadUri)
        ++ " | jq -r '.[] | [.id, .oracle_id, .name, .set, (.collector_number // \"\"), (.rarity // \"unknown\"), (.image_uris.small // \"\"), (.image_uris.normal // \"\")] | @tsv' > \"$tmp\"; "
        "sqlite3 "
        ++ shell_quote(db_file())
        ++ " <<SQL\n"
        "BEGIN;\n"
        "CREATE TEMP TABLE _catalog_import (\n"
        "  id TEXT,\n"
        "  oracle_id TEXT,\n"
        "  name TEXT,\n"
        "  set_code TEXT,\n"
        "  collector_number TEXT,\n"
        "  rarity TEXT,\n"
        "  image_small_uri TEXT,\n"
        "  image_normal_uri TEXT\n"
        ");\n"
        ".mode tabs\n"
        ".import $tmp _catalog_import\n"
        "DELETE FROM catalog_cards;\n"
        "INSERT INTO catalog_cards (\n"
        "  id, oracle_id, name, set_code, collector_number, rarity, image_small_uri, image_normal_uri\n"
        ")\n"
        "SELECT\n"
        "  id, oracle_id, name, set_code, collector_number, rarity, image_small_uri, image_normal_uri\n"
        "FROM _catalog_import;\n"
        "DROP TABLE _catalog_import;\n"
        "COMMIT;\n"
        "SQL",
    case run_shell(Script) of
        {ok, _} -> ok;
        {error, Output} -> {error, simplify_error(Output)}
    end.

mark_probe_succeeded(UpdatedAt) ->
    Sql =
        "INSERT INTO catalog_sync_metadata ("
        "  id, last_probe_at, last_upstream_updated_at, last_refresh_status, last_error_message, updated_at"
        ") VALUES ("
        "  1, CURRENT_TIMESTAMP, "
        ++ sqlite_store:quote(UpdatedAt)
        ++ ", 'succeeded', NULL, CURRENT_TIMESTAMP"
        ++ ") "
        "ON CONFLICT(id) DO UPDATE SET "
        "  last_probe_at = CURRENT_TIMESTAMP,"
        "  last_upstream_updated_at = excluded.last_upstream_updated_at,"
        "  last_refresh_status = 'succeeded',"
        "  last_error_message = NULL,"
        "  updated_at = CURRENT_TIMESTAMP;",
    ok = sqlite_store:exec(Sql),
    ok.

mark_probe_skipped(UpdatedAt) ->
    Sql =
        "INSERT INTO catalog_sync_metadata ("
        "  id, last_probe_at, last_upstream_updated_at, last_refresh_status, last_error_message, updated_at"
        ") VALUES ("
        "  1, CURRENT_TIMESTAMP, "
        ++ sqlite_store:quote(UpdatedAt)
        ++ ", 'skipped', NULL, CURRENT_TIMESTAMP"
        ++ ") "
        "ON CONFLICT(id) DO UPDATE SET "
        "  last_probe_at = CURRENT_TIMESTAMP,"
        "  last_upstream_updated_at = excluded.last_upstream_updated_at,"
        "  last_refresh_status = 'skipped',"
        "  last_error_message = NULL,"
        "  updated_at = CURRENT_TIMESTAMP;",
    ok = sqlite_store:exec(Sql),
    ok.

mark_probe_failed(Reason) ->
    Sql =
        "INSERT INTO catalog_sync_metadata ("
        "  id, last_probe_at, last_upstream_updated_at, last_refresh_status, last_error_message, updated_at"
        ") VALUES ("
        "  1, CURRENT_TIMESTAMP, NULL, 'failed', "
        ++ sqlite_store:quote(Reason)
        ++ ", CURRENT_TIMESTAMP"
        ++ ") "
        "ON CONFLICT(id) DO UPDATE SET "
        "  last_probe_at = CURRENT_TIMESTAMP,"
        "  last_refresh_status = 'failed',"
        "  last_error_message = excluded.last_error_message,"
        "  updated_at = CURRENT_TIMESTAMP;",
    ok = sqlite_store:exec(Sql),
    ok.

db_file() ->
    case os:getenv("TCG_DB_FILE") of
        false -> ?DEFAULT_DB_FILE;
        Value -> Value
    end.

run_shell(Script) ->
    Wrapped =
        "set +e; "
        ++ Script
        ++ "; status=$?; printf '\n__EXIT__:%s' \"$status\"",
    Output = os:cmd("sh -c " ++ shell_quote(Wrapped)),
    case string:split(Output, "__EXIT__:", all) of
        [Body, StatusRaw] ->
            case string:trim(StatusRaw) of
                "0" -> {ok, string:trim(Body)};
                _ -> {error, string:trim(Body)}
            end;
        _ -> {error, string:trim(Output)}
    end.

simplify_error([]) ->
    "unknown error";
simplify_error(Output) ->
    string:trim(Output).

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

parse_rows(Output) ->
    Lines = string:split(Output, "\n", all),
    Reversed = lists:foldl(
        fun(Line, Acc) ->
            case Line of
                [] -> Acc;
                _ ->
                    case string:split(Line, "\t", all) of
                        [Id, Name, SetCode] ->
                            [
                                {
                                    unicode:characters_to_binary(Id),
                                    unicode:characters_to_binary(Name),
                                    unicode:characters_to_binary(SetCode)
                                }
                                | Acc
                            ];
                        _ -> Acc
                    end
            end
        end,
        [],
        Lines
    ),
    lists:reverse(Reversed).
