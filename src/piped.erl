%% @doc
%%   pure function computation that abstract asynchronous activity
%%   with help of reader monad.
-module(piped).
-behaviour(pipe).

-export([
   start_link/1,
   start_link/2,
   start_link/3,
   init/1,
   free/2,
   handle/3,

   a/2,
   b/2,
   require/2,
   defined/2
]).


%%%------------------------------------------------------------------
%%%
%%% factory
%%%
%%%------------------------------------------------------------------   

start_link(Type) ->
   pipe:start_link(?MODULE, [Type], []).

start_link(Type, Opts) ->
   pipe:start_link(?MODULE, [Type], Opts).

start_link(Name, Type, Opts) ->
   pipe:start_link(Name, ?MODULE, [Type], Opts).

init([Type]) ->
   {ok, handle,
      [Type:FMap() || 
         {FMap, Arity} <- Type:module_info(exports),
         Arity =:= 0,
         FMap  =/= start_link,
         FMap  =/= module_info]
   }.

free(_, _) ->
   ok.

%%%------------------------------------------------------------------
%%%
%%% pipe
%%%
%%%------------------------------------------------------------------   

handle(In, Pipe, FMaps) ->
   [FMap([In | Pipe]) || FMap <- FMaps],
   {next_state, handle, FMaps}.


%%%------------------------------------------------------------------
%%%
%%% reader monad api
%%%
%%%------------------------------------------------------------------   

a(Msg, [_|Pipe]) ->
   pipe:a(Msg, Pipe).

b(Msg, [_|Pipe]) ->
   pipe:b(Msg, Pipe).

require(Lens, [In|_]) ->
   case lens:get(Lens, In) of
      {ok, Expect} ->
         {ok, Expect};
      {error, _} = Error ->
         Error
      LensFocusedAt ->
         {ok, LensFocusedAt}
   end.

defined(Lens, [In|_]) ->
   case lens:get(Lens, In) of
      undefined ->
         {error, undefined};
      _ ->
         {ok, In}
   end.

