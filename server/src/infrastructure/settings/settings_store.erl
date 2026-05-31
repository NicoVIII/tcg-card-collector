-module(settings_store).
-export([get/0, update/2, clear/0]).

-define(KEY, tcg_app_settings).
-define(DEFAULT_SORT, <<"card_name">>).
-define(DEFAULT_GROUPING, <<"location">>).

get() ->
    persistent_term:get(?KEY, {?DEFAULT_SORT, ?DEFAULT_GROUPING}).

update(DefaultSort, DefaultGrouping) ->
    persistent_term:put(?KEY, {DefaultSort, DefaultGrouping}),
    nil.

clear() ->
    persistent_term:erase(?KEY),
    nil.
