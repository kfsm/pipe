%% @doc
%%   Example one_for_all supervisor
-module(one_for_all_sup).

-export([start_link/0, init/1]).

start_link() ->
   pipe:supervise(?MODULE, []).

init([]) ->
   {ok,
      {
         {one_for_one, 1, 3600},
         [
            {process, start_link, []},
            {process, start_link, []},
            {process, start_link, []}
         ]
      }
   }.