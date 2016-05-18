%%
%%   Copyright (c) 2012 - 2013, Dmitry Kolesnikov
%%   Copyright (c) 2012 - 2013, Mario Cardona
%%   All Rights Reserved.
%%
%%   Licensed under the Apache License, Version 2.0 (the "License");
%%   you may not use this file except in compliance with the License.
%%   You may obtain a copy of the License at
%%
%%       http://www.apache.org/licenses/LICENSE-2.0
%%
%%   Unless required by applicable law or agreed to in writing, software
%%   distributed under the License is distributed on an "AS IS" BASIS,
%%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%   See the License for the specific language governing permissions and
%%   limitations under the License.
%%
%% @doc
%%   a simple flow - increment integer by 1
-module(flow).
-behaviour(pipe).

%% public api
-export([start_link/0, start_link/1]).

%% pipe call-back
-export([init/1, free/2, add/3]).


%%
%% pipe:start_link spawns new registered process using this module as behavior
start_link() ->
   start_link(inf).

start_link(N) ->
   pipe:start_link(?MODULE, [N], []).


%%
%% The function is called whenever the state machine process is started using either 
%% start_link or start function. It build internal state data structure, defines 
%% initial state transition, etc. The function should return either `{ok, Sid, State}` 
%% or `{error, Reason}`.
init([N]) ->
   {ok, add, N}.

%%
%% The function is called to release resource owned by state machine, it is called when 
%% the process is about to terminate.
free(_, _State) ->
   ok.

%%
%% The state transition function receive any message, which is sent using pipe interface 
%% or any other Erlang message passing operation. The function executes the state 
%% transition, generates output or terminate execution. 
add(X, Pipe, N)
 when X < N ->
   % emit message to side (b) - next element in pipeline  
   pipe:b(Pipe, X + 1),
   {next_state, add, N};

add(X, _Pipe, N)
 when X >= N ->
   io:format("==> ~p~n", [X]),
   {next_state, add, N}.

