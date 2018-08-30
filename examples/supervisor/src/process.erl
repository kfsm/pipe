%% @doc
%%   Example process to feature supervisor behavior
-module(process).
-behaviour(pipe).

-export([
   start_link/0,
   init/1,
   free/2,
   handle/3
]).

start_link() -> 
   pipe:start_link(?MODULE, [], []).

init(_) ->
   error_logger:info_report([
      {stage, self()}
   ]),
   {ok, handle, undefined}.

free(_, _) ->
   ok.

handle(Msg, Pipe, State) ->
   error_logger:info_report([
      {stage, self()},
      {ingress, Msg}
   ]),
   pipe:b(Pipe, Msg),
   {next_state, handle, State}.
