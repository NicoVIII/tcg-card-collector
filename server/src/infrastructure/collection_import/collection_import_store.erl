-module(collection_import_store).
-export([save/4, latest/0, replace_rows/2, clear/0]).

save(Id, SourceName, Status, RowCount) ->
    SourceChecksum = "manual-upload",
    FinishedAtSql =
        case Status of
            <<"succeeded">> -> "CURRENT_TIMESTAMP";
            <<"failed">> -> "CURRENT_TIMESTAMP";
            "succeeded" -> "CURRENT_TIMESTAMP";
            "failed" -> "CURRENT_TIMESTAMP";
            _ -> "NULL"
        end,
    Sql =
        "INSERT INTO import_runs ("
        "  id, source_name, source_checksum, status, started_at, finished_at, imported_row_count"
        ") VALUES ("
        ++ sqlite_store:quote(Id)
        ++ ", "
        ++ sqlite_store:quote(SourceName)
        ++ ", "
        ++ sqlite_store:quote(SourceChecksum)
        ++ ", "
        ++ sqlite_store:quote(Status)
        ++ ", CURRENT_TIMESTAMP, "
        ++ FinishedAtSql
        ++ ", "
        ++ integer_to_list(RowCount)
        ++ ") "
        "ON CONFLICT(id) DO UPDATE SET "
        "  source_name = excluded.source_name,"
        "  source_checksum = excluded.source_checksum,"
        "  status = excluded.status,"
        "  imported_row_count = excluded.imported_row_count,"
        "  finished_at = "
        ++ FinishedAtSql
        ++ ", "
        "  updated_at = CURRENT_TIMESTAMP;",
    ok = sqlite_store:exec(Sql),
    nil.

latest() ->
    Output =
        sqlite_store:query(
            "SELECT id, source_name, status, imported_row_count "
            "FROM import_runs "
            "ORDER BY updated_at DESC, created_at DESC "
            "LIMIT 1;"
        ),
    case parse_latest(Output) of
        {ok, Row} -> {some, Row};
        error -> none
    end.

replace_rows(ImportRunId, Rows) ->
    DeleteSql =
        "DELETE FROM collection_snapshot WHERE import_run_id = "
        ++ sqlite_store:quote(ImportRunId)
        ++ ";",
    ok = sqlite_store:exec(DeleteSql),
    insert_rows(ImportRunId, Rows, 1),
    nil.

clear() ->
    ok = sqlite_store:exec("DELETE FROM collection_snapshot;"),
    ok = sqlite_store:exec("DELETE FROM import_runs;"),
    nil.

insert_rows(_ImportRunId, [], _RowNumber) ->
    ok;
insert_rows(ImportRunId, [{CardName, SetCode, CollectorNumber, Quantity} | Rest], RowNumber) ->
    RowId = iolist_to_binary([ImportRunId, "-row-", integer_to_list(RowNumber)]),
    Sql =
        "INSERT INTO collection_snapshot ("
        "  id, import_run_id, row_number, card_name, set_code, collector_number, finish, language, quantity"
        ") VALUES ("
        ++ sqlite_store:quote(RowId)
        ++ ", "
        ++ sqlite_store:quote(ImportRunId)
        ++ ", "
        ++ integer_to_list(RowNumber)
        ++ ", "
        ++ sqlite_store:quote(CardName)
        ++ ", "
        ++ sqlite_store:quote(SetCode)
        ++ ", "
        ++ sqlite_store:quote(CollectorNumber)
        ++ ", 'nonfoil', 'en', "
        ++ integer_to_list(Quantity)
        ++ ");",
    ok = sqlite_store:exec(Sql),
    insert_rows(ImportRunId, Rest, RowNumber + 1).

parse_latest(Output) ->
    case string:trim(Output) of
        [] -> error;
        Line ->
            case string:split(Line, "\t", all) of
                [Id, SourceName, Status, RowCountRaw] ->
                    case string:to_integer(RowCountRaw) of
                        {error, _} -> error;
                        {RowCount, _Rest} ->
                            {
                                ok,
                                {
                                    unicode:characters_to_binary(Id),
                                    unicode:characters_to_binary(SourceName),
                                    unicode:characters_to_binary(Status),
                                    RowCount
                                }
                            }
                    end;
                _ -> error
            end
    end.
