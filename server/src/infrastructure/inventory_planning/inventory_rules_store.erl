-module(inventory_rules_store).
-export([upsert/3, list/0, delete/1, clear/0]).

-define(TABLE, tcg_inventory_rules).

ensure_table() ->
    case ets:whereis(?TABLE) of
        undefined -> ets:new(?TABLE, [named_table, public, set]);
        _ -> ?TABLE
    end.

upsert(Id, LocationName, Expression) ->
    ensure_table(),
    ets:insert(?TABLE, {Id, LocationName, Expression}),
    nil.

list() ->
    ensure_table(),
    ets:tab2list(?TABLE).

delete(Id) ->
    ensure_table(),
    ets:delete(?TABLE, Id),
    nil.

clear() ->
    case ets:whereis(?TABLE) of
        undefined -> ok;
        _ -> ets:delete_all_objects(?TABLE)
    end,
    nil.
