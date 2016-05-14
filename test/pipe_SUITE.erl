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
   start/1
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
         [start]}
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

start(_Config) ->
   {ok, Pid} = pipe:start(?MODULE, [1], []),
   true = erlang:is_process_alive(Pid),
   ok = pipe:free(Pid),
   timer:sleep(100),
   false = erlang:is_process_alive(Pid),
   ok.



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

handle(_, _, State) ->
   {next_state, handle, State}.

