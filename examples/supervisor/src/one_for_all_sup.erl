%% @doc
%%   Example one_for_all supervisor
-module(one_for_all_sup).

-export([start_link/0, init/1]).

%%
% -define(CHILD(I),            {I,  {I, start_link,   []}, permanent, 5000, worker, dynamic}).
% -define(CHILD(I, Args),      {I,  {I, start_link, Args}, permanent, 5000, worker, dynamic}).
% -define(CHILD(ID, I, Args),  {ID, {I, start_link, Args}, permanent, 5000, worker, dynamic}).

start_link() ->
   pipe:supervisor(?MODULE, []).

init([]) ->
   {ok,
      {
         {one_for_one, 1, 3600},
         [
            process,
            {process, start_link, []},
            {process, start_link, []},
            {process, start_link, []}
         ]
      }
   }.