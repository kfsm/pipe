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
%%    unit test
-module(pipe_tests).
-include_lib("eunit/include/eunit.hrl").

%%%------------------------------------------------------------------
%%%
%%% test pipe stage
%%%
%%%------------------------------------------------------------------

-export([
   init/1
  ,free/2
  ,ioctl/2
  ,handle/3
]).

init(_) ->
   {ok, handle, {}}.

free(_, _) ->
   ok.

ioctl(_, _) ->
   throw(not_supported).

handle({req, X}, Pipe, S) ->
   pipe:ack(Pipe, {ok, X}),
   {next_state, handle, S};

handle(X, Pipe, S) ->
   pipe:b(Pipe, X),
   {next_state, handle, S}.


%%%------------------------------------------------------------------
%%%
%%% management api
%%%
%%%------------------------------------------------------------------

pipe_test_() ->
   {
      setup,
      fun pipe_init/0,
      fun pipe_free/1,
      [
        {"pipe spawn/free",      fun pipe_spawn_free/0}
       ,{"pipe bind",            fun pipe_bind/0}
       ,{"pipe make pipeline",   fun pipe_make_pipeline/0}
       ,{"pipe monitor",         fun pipe_monitor/0}
      ]
   }.

pipe_init() ->
   ok.

pipe_free(_) ->
   ok.

%%
%% pipe stage life cycle test(s)
pipe_spawn_free() ->
   pipe_spawn_free(spawn, fun(X) -> X end),
   pipe_spawn_free(spawn_link, fun(X) -> X end),
   pipe_spawn_free(spawn_monitor, fun(X) -> X end),

   pipe_spawn_free(start, ?MODULE),
   pipe_spawn_free(start_link, ?MODULE).

pipe_spawn_free(Id, Fun)
 when is_function(Fun) ->
   Pid = case pipe:Id(Fun) of
      {X, _} -> X;
      X      -> X
   end,
   ok    = pipe:free(Pid),
   timer:sleep(10),
   false = erlang:is_process_alive(Pid);

pipe_spawn_free(Id, Mod)
 when is_atom(Mod) ->
   {ok, Pid} = pipe:Id(?MODULE, [], []),
   ok        = pipe:free(Pid),
   timer:sleep(10),
   false = erlang:is_process_alive(Pid),

   {ok, P1d} = pipe:Id({local, ?MODULE}, ?MODULE, [], []),
   ok        = pipe:free(P1d),
   timer:sleep(10),
   false = erlang:is_process_alive(P1d).

%%
%% pipe stage(s) bind
pipe_bind() ->
   A = pipe:spawn(fun(X) -> X end),
   B = pipe:spawn(fun(X) -> X end),
   pipe_bind(A, B),
   _ = pipe:free(A),
   _ = pipe:free(B),

   {ok, C} = pipe:start(?MODULE, [], []),
   {ok, D} = pipe:start(?MODULE, [], []),
   pipe_bind(C, D),
   _ = pipe:free(C),
   _ = pipe:free(D).


pipe_bind(A, B) ->
   P = self(),
   {ok, _} = pipe:bind(a, A),
   {ok, _} = pipe:bind(b, A, B),
   {ok, _} = pipe:bind(a, B, A),
   {ok, _} = pipe:bind(b, B),

   {ok, P} = pipe:ioctl(A, a),
   {ok, B} = pipe:ioctl(A, b),
   {ok, A} = pipe:ioctl(B, a),
   {ok, P} = pipe:ioctl(B, b).

%%
%%  
pipe_make_pipeline() ->
   Pids = [pipe:spawn(fun(X) -> X end) || _ <- lists:seq(1, 10)],
   _    = pipe:make(Pids),
   _    = pipe:free(Pids).

%%
%%
pipe_monitor() ->
   Pid = pipe:spawn(fun(X) -> timer:sleep(500), exit(die) end),
   pipe:send(Pid, message),
   {Ref, _} = pipe:monitor(Pid),
   receive
      {'DOWN', Ref, process, Pid, _} ->
         oks
   end.


%%%------------------------------------------------------------------
%%%
%%% asynchronous
%%%
%%%------------------------------------------------------------------

pipeline_io_test_() ->
   {
      setup,
      fun pipeline_io_init/0,
      fun pipeline_io_free/1,
      [
         {"async send to raw", fun pipeline_send_raw/0}
        ,{"async send to fsm", fun pipeline_send_fsm/0}
        ,{"async recv",        fun pipeline_recv/0}
      ]
   }.

pipeline_io_init() ->
   %% make raw pipeline
   Fun = fun(X) -> X end,
   Raw = [pipe:spawn(Fun) || _ <- lists:seq(1, 10)],
   _   = pipe:make(Raw),
   erlang:register(pipe_raw_head, hd(Raw)),
   erlang:register(pipe_raw_tail, lists:last(Raw)),

   %% make fsm pipeline
   Fsm = [erlang:element(2, pipe:start(?MODULE, [], [])) || _ <- lists:seq(1, 10)],
   _   = pipe:make(Fsm),
   erlang:register(pipe_fsm_head, hd(Fsm)),
   erlang:register(pipe_fsm_tail, lists:last(Fsm)),
   Raw ++ Fsm.

pipeline_io_free(Pids) ->
   erlang:unregister(pipe_raw_head),
   erlang:unregister(pipe_raw_tail),
   erlang:unregister(pipe_fsm_head),
   erlang:unregister(pipe_fsm_tail),
   pipe:free(Pids).

%%
%%
pipeline_send_raw() ->
   {ok, _} = pipe:bind(a, erlang:whereis(pipe_raw_head)),
   {ok, _} = pipe:bind(b, erlang:whereis(pipe_raw_tail)),

   pipe:send(pipe_raw_head, message),
   message = pipe:recv(),

   pipe:send(pipe_raw_tail, message),
   message = pipe:recv().

%%
%%
pipeline_send_fsm() ->
   {ok, _} = pipe:bind(a, erlang:whereis(pipe_fsm_head)),
   {ok, _} = pipe:bind(b, erlang:whereis(pipe_fsm_tail)),

   pipe:send(pipe_fsm_head, message),
   message = pipe:recv(),

   pipe:send(pipe_fsm_tail, message),
   message = pipe:recv().

%%
%%
pipeline_recv() ->
   P1 = pipe:spawn(fun(X) -> X end),
   P2 = pipe:spawn(fun(X) -> X end),
   pipe:bind(a, P1),
   pipe:bind(b, P1),

   pipe:send(P1, message),
   message = pipe:recv(P1, 5000, []),

   pipe:send(P2, message),
   {error, timeout} = pipe:recv(1000, [noexit]).


%%%------------------------------------------------------------------
%%%
%%% synchronous
%%%
%%%------------------------------------------------------------------

pipefsm_io_test_() ->
   {
      setup,
      fun pipefsm_io_init/0,
      fun pipefsm_io_free/1,
      [
         {"server call", fun pipefsm_call/0}
        ,{"server cast", fun pipefsm_cast/0}
        ,{"server send", fun pipefsm_send/0}
        %,{"lookup", fun lookup/0}
      ]
   }.

pipefsm_io_init() ->
   {ok, Pid} = pipe:start({local, pipefsm}, ?MODULE, [], []),
   Pid.

pipefsm_io_free(Pid) ->
   pipe:free(Pid).

%%
%%
pipefsm_call() ->
   {ok, message} = pipe:call(pipefsm, {req, message}).

%%
%%
pipefsm_cast() ->
   Ref = pipe:cast(pipefsm, {req, message}),
   receive
      {Ref, {ok, message}} ->
         ok
   end.

%%
%%
pipefsm_send() ->
   {req, message} = pipe:send(pipefsm, {req, message}),
   receive
      {ok, message} ->
         ok
   end.


%%%------------------------------------------------------------------
%%%
%%% private
%%%
%%%------------------------------------------------------------------

