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
   bind/2,
   bind/3,
   make/1,
   a/2, 
   b/2, 
   send/2,
   relay/2,
   recv/0, 
   recv/1,
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
      {init, 1}
     ,{free, 2}
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
-spec(spawn/1      :: (function()) -> pid()).
-spec(spawn_link/1 :: (function()) -> pid()).

spawn(Fun) ->
   erlang:spawn(fun() -> pipe_loop(Fun, undefined, undefined) end).

spawn_link(Fun) ->
   erlang:spawn_link(fun() -> pipe_loop(Fun, undefined, undefined) end).

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
%% make pipeline, return last processes
-spec(make/1 :: ([proc()]) -> pid()).

make([Head | Tail]) ->
   lists:foldl(
      fun(Sink, Source) -> 
         bind(a, Sink, Source),
         bind(b, Source, Sink),
         Sink
      end, 
      Head,
      Tail
   ).


%%
%% send message through pipe
%% TODO: [noyield | noconnect] option
-spec(a/2 :: (pipe(), any()) -> ok).
-spec(b/2 :: (pipe(), any()) -> ok).

a({pipe, A, _}, Msg) ->
   do_send(A, self(), Msg).
b({pipe, _, B}, Msg) ->
   do_send(B, self(), Msg).

%%
%% send pipe message to process 
%% TODO: [noyield | noconnect] option
-spec(send/2 :: (proc(), any()) -> any()).

send(_, undefined) ->
   ok;
send(Sink, Msg) ->
   do_send(Sink, self(), Msg).

%%
%% relay pipe message
%% TODO: [noyield | noconnect] option
-spec(relay/2 :: (pipe(), any()) -> any()).

relay({pipe, A, B}, Msg) ->
   do_send(B, A, Msg).

%%
%% receive pipe message
-spec(recv/0 :: () -> any()).
-spec(recv/1 :: (timeout()) -> any()).

recv() ->
   recv(5000).

recv(Timeout) ->
   receive
   {'$pipe', _Pid, Msg} ->
      Msg
   after Timeout ->
      exit(timeout)
   end.

%%%----------------------------------------------------------------------------   
%%%
%%% private
%%%
%%%----------------------------------------------------------------------------   

%%
%% TODO: [noyield | noconnect] option
do_send(Sink, Pid, Msg)
 when is_pid(Sink) ->
   try 
      erlang:send(Sink, {'$pipe', Pid, Msg}, [noconnect]), 
      erlang:yield(),
      Msg 
   catch _:_ -> 
      Msg 
   end;

do_send(Fun, Pid, Msg)
 when is_function(Fun) ->
   do_send(Fun(Msg), Pid, Msg);

do_send(undefined, _Pid, Msg) ->
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
   {'$pipe', B, Msg} ->
      _ = pipe:send(A, Fun(Msg)),
      pipe_loop(Fun, A, B);
   {'$pipe', _, Msg} ->
      _ = pipe:send(B, Fun(Msg)),
      pipe_loop(Fun, A, B)
   end.
