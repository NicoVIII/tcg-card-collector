-module(inventory_rules_store).
-export([upsert/3, list/0, delete/1, projection/2, clear/0]).

upsert(Id, LocationName, Expression) ->
    Sql =
        "INSERT INTO inventory_rules (id, location_name, expression) VALUES ("
        ++ sqlite_store:quote(Id)
        ++ ", "
        ++ sqlite_store:quote(LocationName)
        ++ ", "
        ++ sqlite_store:quote(Expression)
        ++ ") "
        "ON CONFLICT(id) DO UPDATE SET "
        "  location_name = excluded.location_name,"
        "  expression = excluded.expression,"
        "  updated_at = CURRENT_TIMESTAMP;",
    ok = sqlite_store:exec(Sql),
    nil.

list() ->
    Output =
        sqlite_store:query(
            "SELECT id, location_name, expression "
            "FROM inventory_rules "
            "ORDER BY location_name ASC, id ASC;"
        ),
    parse_rule_rows(Output).

delete(Id) ->
    Sql = "DELETE FROM inventory_rules WHERE id = " ++ sqlite_store:quote(Id) ++ ";",
    ok = sqlite_store:exec(Sql),
    nil.

projection(SortBy, GroupBy) ->
    GroupExpr =
        case GroupBy of
            <<"set_code">> -> "s.set_code";
            "set_code" -> "s.set_code";
            _ -> "r.location_name"
        end,
    SortExpr =
        case SortBy of
            <<"set_code">> -> "s.set_code";
            <<"quantity">> -> "SUM(s.quantity)";
            "set_code" -> "s.set_code";
            "quantity" -> "SUM(s.quantity)";
            _ -> "s.card_name"
        end,
    Sql =
        "WITH latest_succeeded AS ("
        "  SELECT id FROM import_runs"
        "  WHERE status = 'succeeded'"
        "  ORDER BY updated_at DESC, created_at DESC"
        "  LIMIT 1"
        ") "
        "SELECT "
        "  r.location_name,"
        "  s.card_name,"
        "  s.set_code,"
        "  SUM(s.quantity),"
        ++ GroupExpr
        ++ " "
        "FROM collection_snapshot s "
        "JOIN latest_succeeded ls ON s.import_run_id = ls.id "
        "JOIN inventory_rules r ON r.expression = 'set_code=' || s.set_code "
        "GROUP BY r.location_name, s.card_name, s.set_code, "
        ++ GroupExpr
        ++ " "
        "ORDER BY "
        ++ SortExpr
        ++ " ASC, r.location_name ASC, s.card_name ASC;",
    parse_projection_rows(sqlite_store:query(Sql)).

clear() ->
    ok = sqlite_store:exec("DELETE FROM inventory_rules;"),
    nil.

parse_rule_rows(Output) ->
    Lines = string:split(Output, "\n", all),
    Reversed = lists:foldl(
        fun(Line, Acc) ->
            case Line of
                [] -> Acc;
                _ ->
                    case string:split(Line, "\t", all) of
                        [Id, LocationName, Expression] ->
                            [
                                {
                                    unicode:characters_to_binary(Id),
                                    unicode:characters_to_binary(LocationName),
                                    unicode:characters_to_binary(Expression)
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

parse_projection_rows(Output) ->
    Lines = string:split(Output, "\n", all),
    Reversed = lists:foldl(
        fun(Line, Acc) ->
            case Line of
                [] -> Acc;
                _ ->
                    case string:split(Line, "\t", all) of
                        [LocationName, CardName, SetCode, QuantityRaw, GroupValue] ->
                            case string:to_integer(QuantityRaw) of
                                {error, _} -> Acc;
                                {Quantity, _} ->
                                    [
                                        {
                                            unicode:characters_to_binary(LocationName),
                                            unicode:characters_to_binary(CardName),
                                            unicode:characters_to_binary(SetCode),
                                            Quantity,
                                            unicode:characters_to_binary(GroupValue)
                                        }
                                        | Acc
                                    ]
                            end;
                        _ -> Acc
                    end
            end
        end,
        [],
        Lines
    ),
    lists:reverse(Reversed).
