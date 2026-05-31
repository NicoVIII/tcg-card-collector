-module(settings_store).
-export([get/0, update/2, clear/0]).

-define(DEFAULT_SORT, <<"card_name">>).
-define(DEFAULT_GROUPING, <<"location_name">>).

get() ->
    Output =
        sqlite_store:query(
            "SELECT default_sort, default_grouping "
            "FROM app_settings WHERE id = 1 LIMIT 1;"
        ),
    case string:trim(Output) of
        [] -> {?DEFAULT_SORT, ?DEFAULT_GROUPING};
        Line ->
            case string:split(Line, "\t", all) of
                [DefaultSort, DefaultGrouping] ->
                    {
                        unicode:characters_to_binary(DefaultSort),
                        unicode:characters_to_binary(DefaultGrouping)
                    };
                _ -> {?DEFAULT_SORT, ?DEFAULT_GROUPING}
            end
    end.

update(DefaultSort, DefaultGrouping) ->
    Sql =
        "INSERT INTO app_settings (id, default_sort, default_grouping, updated_at) VALUES ("
        "1, "
        ++ sqlite_store:quote(DefaultSort)
        ++ ", "
        ++ sqlite_store:quote(DefaultGrouping)
        ++ ", CURRENT_TIMESTAMP"
        ++ ") "
        "ON CONFLICT(id) DO UPDATE SET "
        "  default_sort = excluded.default_sort,"
        "  default_grouping = excluded.default_grouping,"
        "  updated_at = CURRENT_TIMESTAMP;",
    ok = sqlite_store:exec(Sql),
    nil.

clear() ->
    ok = sqlite_store:exec("DELETE FROM app_settings;"),
    ok = sqlite_store:exec(
        "INSERT OR IGNORE INTO app_settings (id, default_sort, default_grouping) "
        "VALUES (1, 'card_name', 'location_name');"
    ),
    nil.
