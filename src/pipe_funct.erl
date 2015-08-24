%% @doc
%%   pipe functor
-module(pipe_funct).
-behaviour(pipe).

-export([
   init/1,
   free/2,
   handle/3
]).

init([Init, Funct]) ->
   Init(),
   {ok, handle, Funct};

init([Funct]) ->
   {ok, handle, Funct}.

free(_, _Funct) ->
   ok.

handle(In, Pipe, Funct) ->
   case Funct(In) of
      {a, Eg} ->
         pipe:a(Pipe, Eg),
         {next_state, handle, Funct};

      {b, Eg} ->
         pipe:b(Pipe, Eg),
         {next_state, handle, Funct};

      {upgrade, Upgrade} ->
         {next_state, handle, Upgrade};

      _       ->
         {next_state, handle, Funct}
   end. 