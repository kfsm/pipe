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
%% @description
%%
-module(pipe_SUITE).
-include_lib("common_test/include/ct.hrl").

%%
%% common test
-export([
   all/0
  ,groups/0
  ,init_per_suite/1
  ,end_per_suite/1
  ,init_per_group/2
  ,end_per_group/2
]).

-export([
   start/1,
   start_link/1,
   spawn/1,
   spawn_link/1,
   call/1,
   cast/1,
   send/1,
   ioctl/1
]).

%%% pipe behavior 
-export([init/1, free/2, ioctl/2, handle/3]).

%%%----------------------------------------------------------------------------   
%%%
%%% suite
%%%
%%%----------------------------------------------------------------------------   
all() ->
   [
      {group, interface}
   ].

groups() ->
   [
      {interface, [parallel], 
         [start, start_link, spawn, spawn_link,
          call, cast, send, ioctl]}
   ].

%%%----------------------------------------------------------------------------   
%%%
%%% init
%%%
%%%----------------------------------------------------------------------------   
init_per_suite(Config) ->
   Config.

end_per_suite(_Config) ->
   ok.

%% 
%%
init_per_group(_, Config) ->
   Config.

end_per_group(_, _Config) ->
   ok.

%%%----------------------------------------------------------------------------   
%%%
%%% unit test
%%%
%%%----------------------------------------------------------------------------   

%%
start(_Config) ->
   {ok, Pid} = pipe:start(?MODULE, [1], []),
   true = erlang:is_process_alive(Pid),
   ok = pipe:free(Pid),
   ok = wait4free(Pid),
   ok.

%%
start_link(_Config) ->
   {ok, Pid} = pipe:start_link(?MODULE, [1], []),
   true = erlang:is_process_alive(Pid),
   ok = pipe:free(Pid),
   ok = wait4free(Pid),
   ok.

%%
spawn(_Config) ->
   Pid = pipe:spawn(fun(X) -> {b, X} end),
   true = erlang:is_process_alive(Pid),
   ok = pipe:free(Pid),
   ok = wait4free(Pid),
   ok.
   
%%
spawn_link(_Config) ->
   Pid = pipe:spawn_link(fun(X) -> {b, X} end),
   true = erlang:is_process_alive(Pid),
   ok = pipe:free(Pid),
   ok = wait4free(Pid),
   ok.

%%
call(_Config) ->
   {ok, Pid} = pipe:start(?MODULE, [1], []),
   {ok, 1} = pipe:call(Pid, request, 100),
   ok = pipe:free(Pid).

%%
cast(_Config) ->
   {ok, Pid} = pipe:start(?MODULE, [1], []),
   Tx = pipe:cast(Pid, request),
   receive
      {Tx, {ok, 1}} -> 
         ok
      after 100 ->
         exit(timeout)
   end,
   ok = pipe:free(Pid).

%%
send(_Config) ->
   {ok, Pid} = pipe:start(?MODULE, [1], []),
   _ = pipe:send(Pid, request),
   receive
      {Tx, {ok, 1}} ->
         exit(invalid)
      after 100 ->
         ok
   end,
   ok = pipe:free(Pid).

%%
ioctl(_Config) ->
   {ok, Pid} = pipe:start(?MODULE, [1], []),
   1 = pipe:ioctl(Pid, x),
   ok = pipe:ioctl(Pid, {y, "text"}),
   "text" = pipe:ioctl(Pid, y),
   ok = pipe:free(Pid).


%%%----------------------------------------------------------------------------   
%%%
%%% utility
%%%
%%%----------------------------------------------------------------------------   

wait4free(Pid) ->
   case erlang:is_process_alive(Pid) of
      true ->
         timer:sleep(10),
         wait4free(Pid);

      false ->
         ok
   end.


%%%----------------------------------------------------------------------------   
%%%
%%% pipe behavior
%%%
%%%----------------------------------------------------------------------------   

init([X]) ->
   {ok, handle, #{x => X}}.

free(_Reason, _State) ->
   ok.

ioctl({Key, Val}, State) ->
   maps:put(Key, Val, State);

ioctl(Key, State) ->
   maps:get(Key, State).

handle(request, Pipe, #{x := X} = State) ->
   pipe:ack(Pipe, {ok, X}),
   {next_state, handle, State};

handle(_, _, State) ->
   {next_state, handle, State}.

