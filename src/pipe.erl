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
-module(pipe).
-include("pipe.hrl").

-export([start/0]).
-export([behaviour_info/1]).
%% pipe management interface
-export([
   start/3
  ,start/4
  ,start_link/3
  ,start_link/4
  ,spawn/1
  ,spawn_link/1
  ,bind/2
  ,bind/3
  ,make/1
  ,free/1
  ,monitor/1
  ,monitor/2
  ,demonitor/1
  ,ioctl/2
  ,ioctl_/2
]).
%% pipe i/o interface
-export([
   call/2
  ,call/3
  ,cast/2
  ,cast/3
  ,send/2
  ,send/3
  ,emit/3
  ,emit/4
  ,ack/1
  ,ack/2
  ,recv/0 
  ,recv/1
  ,recv/2
  ,recv/3
  ,a/1
  ,a/2 
  ,a/3
  ,b/1
  ,b/2
  ,b/3
  ,pid/1
  ,tx/1
]).
%% pipeline interface
-export([
   spawner/2
  ,spawner/3
  ,spawn/2
  ,spawn/3
]).

%%
%% data types
-type(pipe()    :: {pipe, pid() | tx(), pid()}).
-type(tx()      :: {pid(), reference()} | {reference(), pid()}).
-type(monitor() :: {reference(), pid() | node()}).
-export_type([pipe/0]).

%%%------------------------------------------------------------------
%%%
%%% pipe behavior interface
%%%
%%%------------------------------------------------------------------   

%%
%% pipe behavior
behaviour_info(callbacks) ->
   [
      %%
      %% init pipe stage
      %%
      %% -spec(init/1 :: ([any()]) -> {ok, sid(), state()} | {stop, any()}).
      {init,  1}
   
      %%
      %% free pipe stage
      %%
      %% -spec(free/2 :: (any(), state()) -> ok).
     ,{free,  2}

      %%
      %% optional state i/o control interface
      %%
      %% -spec(ioctl/2 :: (atom() | {atom(), any()}, state()) -> any() | state()).       
      %%,{ioctl, 2}

      %%
      %% state message handler
      %%
      %% -spec(handler/3 :: (any(), pipe(), state()) -> {next_state, sid(), state()} 
      %%                                             |  {stop, any(), state()} 
      %%                                             |  {upgrade, atom(), [any()]}). 
   ];
behaviour_info(_Other) ->
   undefined.


%%
%% RnD application start
start() ->
   application:start(pipe).


%%%------------------------------------------------------------------
%%%
%%% pipe management interface
%%%
%%%------------------------------------------------------------------   

%%
%% start pipe stage / pipe state machine
-spec(start/3 :: (atom(), list(), list()) -> {ok, pid()} | {error, any()}).
-spec(start/4 :: (atom(), atom(), list(), list()) -> {ok, pid()} | {error, any()}).
-spec(start_link/3 :: (atom(), list(), list()) -> {ok, pid()} | {error, any()}).
-spec(start_link/4 :: (atom(), atom(), list(), list()) -> {ok, pid()} | {error, any()}).

start(Mod, Args, Opts) ->
   gen_server:start(?CONFIG_PIPE, [Mod, Args], Opts).
start(Name, Mod, Args, Opts) ->
   gen_server:start(Name, ?CONFIG_PIPE, [Mod, Args], Opts).

start_link(Mod, Args, Opts) ->
   gen_server:start_link(?CONFIG_PIPE, [Mod, Args], Opts).
start_link(Name, Mod, Args, Opts) ->
   gen_server:start_link(Name, ?CONFIG_PIPE, [Mod, Args], Opts).

%%
%% spawn pipe functor stage
%% function is fun/1 :: (any()) -> {a, Msg} | {b, Msg}
-spec(spawn/1         :: (function()) -> pid()).
-spec(spawn_link/1    :: (function()) -> pid()).

spawn(Fun) ->
   {ok, Pid} = start(pipe_funct, [Fun], []),
   Pid.

spawn_link(Fun) ->
   {ok, Pid} = start_link(pipe_funct, [Fun], []),
   Pid.

%%
%% terminate pipeline
-spec(free/1 :: (pid() | [pid()]) -> ok).

free(Pid)
 when is_pid(Pid) ->
   erlang:send(Pid, {'$pipe', self(), '$free'}),
   ok;
free(Pipeline)
 when is_list(Pipeline) ->
   lists:foreach(fun free/1, Pipeline).


%%
%% bind stage to pipeline
-spec(bind/2 :: (a | b, pid()) -> {ok, pid()}).
-spec(bind/3 :: (a | b, pid(), pid()) -> {ok, pid()}).

bind(a, Pids)
 when is_list(Pids) ->
   bind(a, hd(Pids));
bind(b, Pids)
 when is_list(Pids) ->
   bind(b, lists:last(Pids)); 

bind(a, Pid) ->
   ioctl_(Pid, {a, self()});
bind(b, Pid) ->
   ioctl_(Pid, {b, self()}).

bind(a, Pids, A)
 when is_list(Pids) ->
   bind(a, hd(Pids), A);
bind(b, Pids, A)
 when is_list(Pids) ->
   bind(b, lists:last(Pids), A);

bind(a, Pid, A) ->
   ioctl_(Pid, {a, A});
bind(b, Pid, B) ->
   ioctl_(Pid, {b, B}).

%%
%% make pipeline by binding stages
%% return pipeline head
-spec(make/1 :: ([pid()]) -> pid()).

make(Pipeline) ->
   [Head | Tail] = lists:reverse(Pipeline),
   lists:foldl(
      fun(Sink, Source) -> 
         {ok, _} = bind(b, Sink, Source),
         {ok, _} = bind(a, Source, Sink),
         Sink
      end, 
      Head,
      Tail
   ),
   hd(Pipeline).

%%
%% ioctl interface (sync and async)
-spec(ioctl/2  :: (pid(), atom() | {atom(), any()}) -> any()).
-spec(ioctl_/2 :: (pid(), atom() | {atom(), any()}) -> any()).

ioctl(Pid, {Req, Val})
 when is_atom(Req) ->
   call(Pid, {ioctl, Req, Val});
ioctl(Pid, Req)
 when is_atom(Req) ->
   call(Pid, {ioctl, Req}).

ioctl_(Pid, {Req, Val})
 when is_atom(Req) ->
   send(Pid, {ioctl, Req, Val}), 
   {ok, Val}.


%%
%% monitor process or node. The process receives messages:
%%   {'DOWN', monitor(), process, pid(), reason()}
%%   {nodedown, monitor()}
-spec(monitor/1 :: (pid()) -> monitor()).
-spec(monitor/2 :: (atom(), pid()) -> monitor()).

monitor(Pid) ->
   pipe:monitor(process, Pid).

monitor(process, Pid) ->
   try erlang:monitor(process, Pid) of
      Ref ->
         {process, Ref, Pid}
   catch error:_ ->
      % unable to set monitor, fall-back to node monitor
      pipe:monitor(node, erlang:node(Pid))
   end;

monitor(node, Node) ->
   monitor_node(Node, true),
   {node, erlang:make_ref(), Node}.
 
%%
%% release process monitor
-spec(demonitor/1 :: (monitor()) -> ok).

demonitor({process, Ref, _Pid}) ->
   erlang:demonitor(Ref, [flush]);

demonitor({node, _, Node}) ->
   monitor_node(Node, false),
   receive
      {nodedown, Node} -> 
         ok
   after 0 ->
      ok 
   end.

%%%------------------------------------------------------------------
%%%
%%% pipe i/o interface
%%%
%%%------------------------------------------------------------------   


%%
%% make synchronous request to process
-spec(call/2 :: (pid(), any()) -> any()).
-spec(call/3 :: (pid(), any(), timeout()) -> any()).

call(Pid, Msg) ->
   call(Pid, Msg, ?CONFIG_TIMEOUT).
call(Pid, Msg, Timeout) ->
   Ref = {_, Tx, _} = pipe:monitor(process, Pid),
   catch erlang:send(Pid, {'$pipe', {self(), Tx}, Msg}, [noconnect]),
   receive
   {Tx, Reply} ->
      pipe:demonitor(Ref),
      Reply;
   {'DOWN', Tx, _, _, noconnection} ->
      pipe:demonitor(Ref),
      exit({nodedown, erlang:node(Pid)});
   {'DOWN', Tx, _, _, Reason} ->
      pipe:demonitor(Ref),
      exit(Reason);
   {nodedown, Node} ->
      pipe:demonitor(Ref),
      exit({nodedown, Node})
   after Timeout ->
      pipe:demonitor(Ref),
      exit(timeout)
   end.

%%
%% cast asynchronous request to process
%%   Options:
%%      yield     - suspend current processes
%%      noconnect - do not connect to remote node
-spec(cast/2 :: (pid(), any()) -> reference()).
-spec(cast/3 :: (pid(), any(), list()) -> reference()).

cast(Pid, Msg) ->
   cast(Pid, Msg, []).

cast(Pid, Msg, Opts) ->
   Tx = erlang:make_ref(),
   pipe_send(Pid, {Tx, self()}, Msg, Opts),
   Tx.

%%
%% send asynchronous request to process 
%%   Options:
%%      yield     - suspend current processes
%%      noconnect - do not connect to remote node
-spec(send/2 :: (pid(), any()) -> any()).
-spec(send/3 :: (pid(), any(), list()) -> any()).

send(Pid, Msg) ->
   send(Pid, Msg, []).
send(Pid, Msg, Opts) ->
   pipe_send(Pid, self(), Msg, Opts).

%%
%% send asynchronous request to process using existed pipe instance
-spec(emit/3 :: (pipe(), pid(), any()) -> any()).
-spec(emit/4 :: (pipe(), pid(), any(), list()) -> any()).

emit(Pipe, Pid, Msg) ->
   emit(Pipe, Pid, Msg, []).

emit({pipe, A, _}, Pid, Msg, Opts) ->
   pipe_send(Pid, A, Msg, Opts).

%%
%% send message through pipe
%%   Options:
%%      yield     - suspend current processes
%%      noconnect - do not connect to remote node
-spec(a/2 :: (pipe(), any()) -> ok).
-spec(a/3 :: (pipe(), any(), list()) -> ok).
-spec(b/2 :: (pipe(), any()) -> ok).
-spec(b/3 :: (pipe(), any(), list()) -> ok).

a({pipe, Pid, _}, Msg)
 when is_pid(Pid) orelse is_atom(Pid) ->
   pipe:send(Pid, Msg);
a({pipe, {Pid, Tx}, _}, Msg)
 when is_pid(Pid), is_reference(Tx) ->
   try erlang:send(Pid, {Tx, Msg}), Msg catch _:_ -> Msg end;
a({pipe, {Tx, Pid}, _}, Msg)
 when is_pid(Pid), is_reference(Tx) ->
   try erlang:send(Pid, {Tx, Msg}), Msg catch _:_ -> Msg end.

a({pipe, A, _}, Msg, Opts) ->
   pipe:send(A, Msg, Opts).

b({pipe, _, B}, Msg) ->
   pipe:send(B, Msg).

b({pipe, _, B}, Msg, Opts) ->
   pipe:send(B, Msg, Opts).

%%
%% acknowledge message / request
-spec(ack/1 :: (pid()) -> ok).
-spec(ack/2 :: (pipe() | tx(), any()) -> any()).

ack({pipe, A, _}) ->
   ack(A);
ack(_) ->
   ok.

ack({pipe, A, _}, Msg) ->
   ack(A, Msg);
ack({Pid, Tx}, Msg)
 when is_pid(Pid), is_reference(Tx) ->
   % backward compatible with gen_server:reply
   try erlang:send(Pid, {Tx, Msg}), Msg catch _:_ -> Msg end;
ack({Tx, Pid}, Msg)
 when is_pid(Pid), is_reference(Tx) ->
   try erlang:send(Pid, {Tx, Msg}), Msg catch _:_ -> Msg end;
ack(Pid, Msg)
 when is_pid(Pid) orelse is_atom(Pid) ->
   try erlang:send(Pid, Msg) catch _:_ -> Msg end.

%%
%% receive pipe message
%%  Options
%%    noexit - opts returns {error, timeout} instead of exit signal
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
      recv_error(Opts, timeout)
   end.

recv(Pid, Timeout, Opts) ->
   Ref  = {_, Tx, _} = pipe:monitor(process, Pid),
   receive
   {'$pipe', Pid, Msg} ->
      pipe:demonitor(Ref),
      Msg;
   {'DOWN', Tx, _, _, noconnection} ->
      pipe:demonitor(Ref),
      recv_error(Opts, {nodedown, erlang:node(Pid)});
   {'DOWN', Tx, _, _, Reason} ->
      pipe:demonitor(Ref),
      recv_error(Opts, Reason);
   {nodedown, Node} ->
      pipe:demonitor(Ref),
      recv_error(Opts, {nodedown, Node})
   after Timeout ->
      recv_error(Opts, timeout)
   end.
   
recv_error([noexit], Reason) ->
   {error, Reason};
recv_error(_, Reason) ->
   exit(Reason).


%%
%% return pid() of pipe processes
-spec(a/1 :: (pipe()) -> pid() | undefined).
-spec(b/1 :: (pipe()) -> pid() | undefined).

a({pipe, {_, A}, _})
 when is_pid(A) -> 
   A;
a({pipe, {A, _}, _})
 when is_pid(A) -> 
   A;
a({pipe, A, _}) ->
   A. 
b({pipe, _, B}) -> 
   B.

%%
%% extract transaction pid
-spec(pid/1 :: (pipe()) -> pid() | undefined).

pid(Pipe) ->
   pipe:a(Pipe).

%%
%% extract transaction reference
-spec(tx/1 :: (pipe()) -> reference() | undefined).

tx({pipe, {_Pid, Tx}, _})
 when is_reference(Tx) ->
   Tx;
tx({pipe, {Tx, _Pid}, _})
 when is_reference(Tx) ->
   Tx;
tx({pipe, _, _}) ->
   undefined.

%%%----------------------------------------------------------------------------   
%%%
%%% private
%%%
%%%----------------------------------------------------------------------------   


%%
%% defines new pipeline
-spec(spawner/2 :: (atom(), list()) -> {ok, pid()} | {error, any()}).
-spec(spawner/3 :: (atom(), atom(), list()) -> {ok, pid()} | {error, any()}).

spawner(Name, Mod, Opts) ->
   supervisor:start_child(pipe_spawner_sup, [Name, Mod, [{owner, self()}|Opts]]).

spawner(Mod, Opts) ->
   supervisor:start_child(pipe_spawner_sup, [Mod, [{owner, self()}|Opts]]).

%%
%% spawn pipeline instance 
%%  Flags
%%    nopipe - do not bind process to new pipeline
%%    iob2b  - bind b-to-b 
-spec(spawn/2 :: (pid(), list()) -> {ok, pid()} | {error, any()}).
-spec(spawn/3 :: (pid(), list(), list()) -> {ok, pid()} | {error, any()}).

spawn(Pid, Opts) ->
   pipe:spawn(Pid, Opts, []).

spawn(Pid, Opts, Flags) ->
   pipe:call(Pid, {spawn, Opts, Flags}).

%%%----------------------------------------------------------------------------   
%%%
%%% private
%%%
%%%----------------------------------------------------------------------------   

%%
%% send message through pipe
pipe_send(Pid, Tx, Msg, Opts)
 when ?is_pid(Pid) ->
   try
      pipe_send_msg(Pid, {'$pipe', Tx, Msg}, lists:member(noconnect, Opts)),
      pipe_yield(lists:member(yield, Opts)),
      Msg
   catch error:_ ->
      Msg
   end;
pipe_send(Fun, Tx, Msg, Opts)
 when is_function(Fun) ->
   pipe_send(Fun(Msg), Tx, Msg, Opts).

%%
%% send message to pipe process
pipe_send_msg(Pid, Msg, false) ->
   erlang:send(Pid, Msg, []);
pipe_send_msg(Pid, Msg, true) ->
   erlang:send(Pid, Msg, [noconnect]).

%%
%% yield current process
pipe_yield(false) -> ok;
pipe_yield(true)  -> erlang:yield().


