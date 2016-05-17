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
%%   A simple pin-code state machine (based on an example from the OTP system documentation)
%%
-module(pincode).
-behaviour(pipe).

%% public api
-export([start_link/1, digit/1, reset/0, check/0]).

%% pipe call-back
-export([init/1, free/2, locked/3, unlocked/3]).


%%
%% pipe:start_link spawns new registered process using this module as behavior
start_link(Code) ->
   pipe:start_link({local, ?MODULE}, ?MODULE, [Code], []).

%%
%% supplies digit to state machine
digit(Digit)
 when Digit >= 0, Digit =< 9 ->
   pipe:send(?MODULE, {digit, Digit}).

%%
%% reset state machine to initial state
reset() ->
   pipe:send(?MODULE, reset).

%%
%% check pin-code status
check() ->
   pipe:call(?MODULE, check).


%%%------------------------------------------------------------------
%%%
%%% behavior 
%%%
%%%------------------------------------------------------------------   

%%
%% The function is called whenever the state machine process is started using either 
%% start_link or start function. It build internal state data structure, defines 
%% initial state transition, etc. The function should return either `{ok, Sid, State}` 
%% or `{error, Reason}`.
init([Code]) ->
   {ok, locked, {[], lists:reverse(Code)}}.

%%
%% The function is called to release resource owned by state machine, it is called when 
%% the process is about to terminate.
free(_, _State) ->
   ok.

%%
%% The state transition function receive any message, which is sent using pipe interface 
%% or any other Erlang message passing operation. The function executes the state 
%% transition, generates output or terminate execution. 
%%

%%
%% locked state
locked({digit, Digit}, _Pipe, {SoFar, Code}) ->
   case [Digit|SoFar] of
      % if the new digit completes a sequence that matches the code then unlocks the lock
      Code ->
         % pin-code is correct, unlock state machine.
         % set-up inactivity timeout for 10 seconds.
         {next_state, unlocked, {[], Code}, 10000};

      % partial pin-code is entered
      Prefix when length(Prefix) < length(Code) ->
         {next_state, locked, {Prefix, Code}};

      % wrong pin-code
      _ ->
         {next_state, locked, {[], Code}}
   end;

locked(reset, _Pipe, {_, Code}) ->
   % reset state machine to initial state
   {next_state, locked, {[], Code}};

locked(check, Pipe, State) ->
   % client process checks the state machine status. 
   % acknowledge message and reply to client
   pipe:ack(Pipe, locked),
   {next_state, locked, State}.

%%
%% unlocked state
unlocked(reset, _Pipe, {_, Code}) ->
   % reset state machine to initial state
   {next_state, locked, {[], Code}};

unlocked(timeout, _Pipe, {_, Code}) ->
   % reset state machine to initial state
   {next_state, locked, {[], Code}};

unlocked(check, Pipe, State) ->
   % client process checks the state machine status. 
   % acknowledge message and reply to client
   pipe:ack(Pipe, unlocked),
   {next_state, unlocked, State, 10000}.

