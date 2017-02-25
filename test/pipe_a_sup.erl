-module(pipe_a_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

%%
-define(CHILD(Type, I),            {I,  {I, start_link,   []}, permanent, 5000, Type, dynamic}).
-define(CHILD(Type, I, Args),      {I,  {I, start_link, Args}, permanent, 5000, Type, dynamic}).
-define(CHILD(Type, ID, I, Args),  {ID, {I, start_link, Args}, permanent, 5000, Type, dynamic}).

%%
start_link() ->
   pipe:supervisor(?MODULE, []).
   
init([]) -> 
   {ok,
      {
         {one_for_one, 4, 1800},
         [
            ?CHILD(worker, a, pipe_a, [])
           ,?CHILD(worker, b, pipe_a, [])
           ,?CHILD(worker, c, pipe_a, [])
           ,?CHILD(worker, d, pipe_a, [])
         ]
      }
   }.

