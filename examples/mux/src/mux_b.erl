%% @description
%%   
-module(mux_b).
-behaviour(pipe).

-export([
   start_link/1,
   init/1,
   free/2,
   handle/3
]).

%%%----------------------------------------------------------------------------   
%%%
%%% Factory
%%%
%%%----------------------------------------------------------------------------   

start_link(State) ->
   pipe:start_link(?MODULE, [State], []).

init([State]) ->
   {ok, handle, State}.

free(_Reason, _State) ->
   ok.

%%%----------------------------------------------------------------------------   
%%%
%%% FSM
%%%
%%%----------------------------------------------------------------------------   

handle(req, Pipe, State) ->
   pipe:a(Pipe, {req, State}),
   {next_state, handle, State};

handle(_, _Pipe, State) ->
   {next_state, handle, State}.