-module(card_catalog_store).
-export([upsert/3, list/0, clear/0]).

-define(TABLE, tcg_card_catalog).

ensure_table() ->
    case ets:whereis(?TABLE) of
        undefined -> ets:new(?TABLE, [named_table, public, set]);
        _ -> ?TABLE
    end.

upsert(Id, Name, SetCode) ->
    ensure_table(),
    ets:insert(?TABLE, {Id, Name, SetCode}),
    nil.

list() ->
    ensure_table(),
    ets:tab2list(?TABLE).

clear() ->
    case ets:whereis(?TABLE) of
        undefined -> ok;
        _ -> ets:delete_all_objects(?TABLE)
    end,
    nil.
