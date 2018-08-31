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
-export([all/0]).

-export([
   start_link/1,
   call/1,
   cast/1,
   send/1,
   ioctl/1,
   hibernate/1,
   stop/1,
   upgrade/1
]).

all() ->
   [Test || {Test, NAry} <- ?MODULE:module_info(exports), 
      Test =/= module_info,
      NAry =:= 1
   ].

%%
%%
start_link(_) ->
   process_flag(trap_exit, true),
   {ok, Pid} = pipe:start_link(process, [], []),
   ok = pipe:free(Pid),
   dead = shutdown(Pid).

%%
%%
call(_) ->
   process_flag(trap_exit, true),
   {ok, Pid} = pipe:start_link(process, [], []),

   ok = pipe:call(Pid, do_next_state),
   ok = pipe:call(Pid, do_reply),
   ok = gen_server:call(Pid, do_next_state),
   ok = gen_server:call(Pid, do_reply),

   ok = pipe:free(Pid),
   dead = shutdown(Pid).

%%
%%
cast(_) ->
   process_flag(trap_exit, true),
   {ok, Pid} = pipe:start_link(process, [], []),

   A = pipe:cast(Pid, do_next_state),
   B = pipe:cast(Pid, do_reply),
   ok = recv_from(A),
   ok = recv_from(B),

   ok = pipe:free(Pid),
   dead = shutdown(Pid).   

%%
%%
send(_) ->
   process_flag(trap_exit, true),
   {ok, Pid} = pipe:start_link(process, [], []),

   pipe:send(Pid, do_next_state),
   pipe:send(Pid, do_reply),

   ok = pipe:free(Pid),
   dead = shutdown(Pid).

%%
%%
ioctl(_) ->
   process_flag(trap_exit, true),
   {ok, Pid} = pipe:start_link(process, [], []),

   ok = pipe:ioctl(Pid, {register, 10}),
   10 = pipe:ioctl(Pid, register),

   ok = pipe:free(Pid),
   dead = shutdown(Pid).   

%%
%%
hibernate(_) ->
   process_flag(trap_exit, true),
   {ok, Pid} = pipe:start_link(process, [], []),

   ok = pipe:call(Pid, do_next_state_hibernate),
   ok = pipe:call(Pid, do_reply_hibernate),

   ok = pipe:free(Pid),
   dead = shutdown(Pid).

%%
%%
stop(_) ->
   process_flag(trap_exit, true),
   {ok, Pid} = pipe:start_link(process, [], []),

   ok = pipe:call(Pid, do_stop),

   dead = shutdown(Pid).


%%
%%
upgrade(_) ->
   process_flag(trap_exit, true),
   {ok, Pid} = pipe:start_link(process, [], []),

   ok = pipe:call(Pid, do_upgrade),
   ok = pipe:call(Pid, do_reply),

   ok = pipe:free(Pid),
   dead = shutdown(Pid).


%%%------------------------------------------------------------------
%%%
%%% helper
%%%
%%%------------------------------------------------------------------   

%%
%%
shutdown(Pid) ->
   shutdown(Pid, shutdown).

shutdown(Pid, Reason) ->
   Ref = erlang:monitor(process, Pid),
   exit(Pid, Reason),
   receive
      {'DOWN', Ref, process, Pid, noproc} ->
         dead;
      {'DOWN', Ref, process, Pid, killed} ->
         ok;
      {'DOWN', Ref, process, Pid, Reason} ->
         ok
   end.

%%
%%
recv_from(Tx) ->
   receive
      {Tx, Msg} -> 
         Msg
      after 100 ->
         exit(timeout)
   end.

%%
%%
send_to(Sup, Msg) ->
   pipe:send(pipe:head(Sup), Msg),
   receive
      {ok, Result} -> Result
   after 100  -> 
      ct:fail(timeout)
   end.

