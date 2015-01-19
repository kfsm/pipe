%% @description
%%   
-module(mux_a).
-behaviour(pipe).

-export([
   start_link/0,
   init/1,
   free/2,
   handle/3
]).

%%%----------------------------------------------------------------------------   
%%%
%%% Factory
%%%
%%%----------------------------------------------------------------------------   

start_link() ->
   pipe:start_link(?MODULE, [], []).

init([]) ->
   erlang:send(self(), run),
   {ok, handle, []}.

free(_Reason, _State) ->
   ok.

%%%----------------------------------------------------------------------------   
%%%
%%% FSM
%%%
%%%----------------------------------------------------------------------------   

handle(run, _Pipe, State) ->
   pipe:send(mux_m, req),
   {next_state, handle, State};

handle({req, X}, _Pipe, State) ->
   error_logger:error_report([{a, X}]),
   {stop, normal, State}.