%% @description
%%   
-module(mux_m).
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

start_link(Pool) ->
   pipe:start_link({local, ?MODULE}, ?MODULE, [Pool], []).

init([Pool]) ->
   {ok, handle, Pool}.

free(_Reason, _State) ->
   ok.

%%%----------------------------------------------------------------------------   
%%%
%%% FSM
%%%
%%%----------------------------------------------------------------------------   

handle(req, Pipe, [Head | Tail]) ->
   %% client requested services
   pipe:emit(Pipe, Head, req),
   {next_state, handle, Tail ++ [Head]}; 

handle(_, _Pipe, State) ->
   {next_state, handle, State}.