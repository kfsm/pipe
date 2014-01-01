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
%%   a pipeline is a series of Erlang processes through which messages flows.
%%   the pipeline organizes complex processing tasks through several simple 
%%   Erlang processes, which are called 'stages'. Each stage in a pipeline 
%%   receives message from other pipeline stages, processes them in some way,
%%   and sends transformed message back to the pipeline. 
%%
%%   the pipe is defined as a tuple containing either identities of
%%   predecessor / source (a) and successor / sink (b) stages or 
%%   computation to discover them based on message content.
%%   (a)--(stage)-->(b)
%%
-module(pipe).
-include("pipe.hrl").

-export([
   start/3,
   start/4,
   start_link/3,
   start_link/4,
   spawn/1,
   spawn_link/1,
   spawn_monitor/1,
   bind/2,
   bind/3,
   make/1,
   free/1,
   a/1,
   a/2, 
   a/3,
   b/1,
   b/2,
   b/3, 
   send/2,
   send/3,
   relay/2,
   relay/3,
   recv/0, 
   recv/1,
   recv/2,
   ioctl/2,
   behaviour_info/1
]).

-export_type([pipe/0]).

-type(pipe() :: {pipe, proc(), proc()}).
-type(proc() :: atom() | {atom(), atom()} | {global, atom()} | pid() | function()).
-type(name() :: {local, atom()} | {global, atom()}).

-define(CONTAINER, pipe_process).

%%
%% pipe behavior
behaviour_info(callbacks) ->
   [
      {init,  1}
     ,{free,  2}
     ,{ioctl, 2}
   ];
behaviour_info(_Other) ->
   undefined.

%%
%% start pipe process
-spec(start/3 :: (atom(), list(), list()) -> {ok, pid()} | {error, any()}).
-spec(start/4 :: (name(), atom(), list(), list()) -> {ok, pid()} | {error, any()}).
-spec(start_link/3 :: (atom(), list(), list()) -> {ok, pid()} | {error, any()}).
-spec(start_link/4 :: (name(), atom(), list(), list()) -> {ok, pid()} | {error, any()}).

start(Mod, Args, Opts) ->
   gen_server:start(?CONTAINER, [Mod, Args], Opts).
start(Name, Mod, Args, Opts) ->
   gen_server:start(Name, ?CONTAINER, [Mod, Args], Opts).

start_link(Mod, Args, Opts) ->
   gen_server:start_link(?CONTAINER, [Mod, Args], Opts).
start_link(Name, Mod, Args, Opts) ->
   gen_server:start_link(Name, ?CONTAINER, [Mod, Args], Opts).

%%
%% spawn stateless pipe handler
-spec(spawn/1         :: (function()) -> pid()).
-spec(spawn_link/1    :: (function()) -> pid()).
-spec(spawn_monitor/1 :: (function()) -> {pid(), reference()}).

spawn(Fun) ->
   erlang:spawn(fun() -> pipe_loop(Fun, undefined, undefined) end).

spawn_link(Fun) ->
   erlang:spawn_link(fun() -> pipe_loop(Fun, undefined, undefined) end).

spawn_monitor(Fun) ->
   erlang:spawn_monitor(fun() -> pipe_loop(Fun, undefined, undefined) end).

%%
%% bind process to pipeline
-spec(bind/2 :: (a | b, pid()) -> ok).
-spec(bind/3 :: (a | b, pid(), pid()) -> ok).

bind(Side, Pid) ->
   bind(Side, Pid, self()).

bind(a, Pid, A) ->
   try erlang:send(Pid, {'$pipe', '$a', A}, [noconnect]), ok catch _:_ -> ok end;

bind(b, Pid, B) ->
   try erlang:send(Pid, {'$pipe', '$b', B}, [noconnect]), ok catch _:_ -> ok end.


%%
%% make pipeline, return pipeline head
-spec(make/1 :: ([proc()]) -> pid()).

make(Pipeline) ->
   [Head | Tail] = lists:reverse(Pipeline),
   lists:foldl(
      fun(Sink, Source) -> 
         bind(b, Sink, Source),
         bind(a, Source, Sink),
         Sink
      end, 
      Head,
      Tail
   ).

%%
%% terminate pipeline
-spec(free/1 :: ([proc()]) -> ok).

free(Pipeline) ->
   lists:foreach(
      fun
      ({Pid, Ref}) ->
         _ = erlang:demonitor(Ref, [flush]),
         erlang:send(Pid, {'$pipe', self(), '$free'});
      (Pid) -> 
         erlang:send(Pid, {'$pipe', self(), '$free'}) 
      end,
      Pipeline
   ).

%%
%% return pid() of pipe processes
-spec(a/1 :: (pipe()) -> pid()).
-spec(b/1 :: (pipe()) -> pid()).

a({pipe, A, _}) -> 
   A.
b({pipe, _, B}) -> 
   B.


%%
%% send message through pipe
%%    Options:
%%       noyield   - do not suspend current processes
%%       noconnect - do not connect remote node
%%       
-spec(a/2 :: (pipe(), any()) -> ok).
-spec(a/3 :: (pipe(), any(), list()) -> ok).
-spec(b/2 :: (pipe(), any()) -> ok).
-spec(b/3 :: (pipe(), any(), list()) -> ok).

a({pipe, A, _}, Msg) ->
   do_send(A, self(), Msg).
a({pipe, A, _}, Msg, Opts) ->
   do_send(A, self(), Msg, Opts).

b({pipe, _, B}, Msg) ->
   do_send(B, self(), Msg).
b({pipe, _, B}, Msg, Opts) ->
   do_send(B, self(), Msg, Opts).

%%
%% send pipe message to process 
%%    Options:
%%       noyield   - do not suspend current processes
%%       noconnect - do not connect remote node
-spec(send/2 :: (proc(), any()) -> any()).
-spec(send/3 :: (proc(), any(), list()) -> any()).

send(_, undefined) ->
   ok;
send(Sink, Msg) ->
   do_send(Sink, self(), Msg).

send(_, undefined, _Opts) ->
   ok;
send(Sink, Msg, Opts) ->
   do_send(Sink, self(), Msg, Opts).

%%
%% relay pipe message
%%    Options:
%%       noyield   - do not suspend current processes
%%       noconnect - do not connect remote node
-spec(relay/2 :: (pipe(), any()) -> any()).
-spec(relay/3 :: (pipe(), any(), list()) -> any()).

relay({pipe, A, B}, Msg) ->
   do_send(B, A, Msg).

relay({pipe, A, B}, Msg, Opts) ->
   do_send(B, A, Msg, Opts).

%%
%% receive pipe message
%%   noexit opts returns {error, timeout} instead of exit signal
-spec(recv/0 :: () -> any()).
-spec(recv/1 :: (timeout()) -> any()).
-spec(recv/2 :: (timeout(), list()) -> any()).
-spec(recv/3 :: (pid(), timeout(), list()) -> any()).

recv() ->
   recv(5000).

recv(Timeout) ->
   recv(Timeout, []).

recv(Timeout, Opts) ->
   receive
   {'$pipe', _Pid, Msg} ->
      Msg
   after Timeout ->
      recv_timeout(Opts)
   end.

recv(Pid, Timeout, Opts) ->
   receive
   {'$pipe', Pid, Msg} ->
      Msg
   after Timeout ->
      recv_timeout(Opts)
   end.
   
recv_timeout([noexit]) ->
   {error, timeout};
recv_timeout(_) ->
   exit(timeout).

%%
%% ioctl interface
-spec(ioctl/2 :: (proc(), atom() | {atom(), any()}) -> any()).

ioctl(Pid, {Req, Val})
 when is_atom(Req) ->
   gen_server:call(Pid, {ioctl, Req, Val});
ioctl(Pid, Req)
 when is_atom(Req) ->
   gen_server:call(Pid, {ioctl, Req}).

%%
%% stream interface
-spec(stream/1 :: (timeout()) -> any()).
-spec(stream/2 :: (pid(), timeout()) -> any()).

stream(Timeout) ->
   stream:new(pipe:recv(Timeout), fun() -> stream(Timeout) end).

stream(Pid, Timeout) ->
   stream:new(pipe:recv(Pid, Timeout, []), fun() -> stream(Pid, Timeout) end).



%%%----------------------------------------------------------------------------   
%%%
%%% private
%%%
%%%----------------------------------------------------------------------------   

%%
%%
do_send(Sink, Pid, Msg) ->
   do_send(Sink, Pid, Msg, [noyield, noconnect]).

do_send(Sink, Pid, Msg, Opts)
 when is_pid(Sink) ->
   try 
      % send message
      case lists:member(noconnect, Opts) of
         true  -> erlang:send(Sink, {'$pipe', Pid, Msg}, [noconnect]);
         false -> erlang:send(Sink, {'$pipe', Pid, Msg}, [])
      end,

      % switch context
      case lists:member(noyield, Opts) of
         true  -> ok;
         false -> erlang:yield()
      end,
      Msg 
   catch _:_ -> 
      Msg 
   end;

do_send(Fun, Pid, Msg, Opts)
 when is_function(Fun) ->
   do_send(Fun(Msg), Pid, Msg, Opts);

do_send(undefined, _Pid, Msg, _Opts) ->
   Msg.

%%
%% pipe loop
pipe_loop(Fun, A, B) ->
   receive
   {'$pipe', '$a', Pid} ->
      ?DEBUG("pipe ~p: bind a to ~p", [self(), Pid]),
      pipe_loop(Fun, Pid, B);
   {'$pipe', '$b', Pid} ->
      ?DEBUG("pipe ~p: bind a to ~p", [self(), Pid]),
      pipe_loop(Fun, A, Pid);
   {'$pipe', Pid, '$free'} ->
      ?DEBUG("pipe ~p: free by ~p", [self(), Pid]),
      ok;
   {'$pipe', B, Msg} ->
      _ = pipe:send(A, Fun(Msg)),
      pipe_loop(Fun, A, B);
   {'$pipe', _, Msg} ->
      _ = pipe:send(B, Fun(Msg)),
      pipe_loop(Fun, A, B)
   end.
