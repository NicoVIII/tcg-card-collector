-module(collection_import_store).
-export([save/4, latest/0, clear/0]).

-define(KEY, tcg_collection_import_latest).

save(Id, SourceName, Status, RowCount) ->
    persistent_term:put(?KEY, {Id, SourceName, Status, RowCount}),
    nil.

latest() ->
    case persistent_term:get(?KEY, undefined) of
        undefined -> none;
        {Id, SourceName, Status, RowCount} ->
            {some, {Id, SourceName, Status, RowCount}}
    end.

clear() ->
    persistent_term:erase(?KEY),
    nil.
