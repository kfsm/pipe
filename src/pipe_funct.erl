%% @doc
%%   pipe functor
-module(pipe_funct).
-behaviour(pipe).

-export([
   init/1,
   free/2,
   handle/3
]).

init([Funct]) ->
   {ok, handle, Funct}.

free(_, _Funct) ->
   ok.

handle(In, Pipe, Funct) ->
   case Funct(In) of
      {a, Eg} ->
         pipe:a(Pipe, Eg);
      {b, Eg} ->
         pipe:b(Pipe, Eg);
      _       ->
         ok
   end,
   {next_state, handle, Funct}. 