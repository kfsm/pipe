%% @doc
%%   Example one_for_all inline supervisor
-module(composition_sup).


-export([start_link/0]).


start_link() ->
   pipe:supervise(pure, {one_for_all, 2, 10}, [
      fun(X) -> X end,
      fun(X) -> X end,
      fun(X) -> X end
   ]).