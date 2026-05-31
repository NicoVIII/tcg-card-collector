-module(card_catalog_store).
-export([upsert/3, list/0, clear/0]).

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
