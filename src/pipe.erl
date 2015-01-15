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

-export([
   % pipe management interface
   start/3
  ,start/4
  ,start_link/3
  ,start_link/4
  ,spawn/1
  ,spawn_link/1
  ,spawn_monitor/1
  ,loop/1
  ,bind/2
  ,bind/3
  ,make/1
  ,free/1
  ,monitor/1
  ,monitor/2
  ,demonitor/1
  ,ioctl/2
  ,ioctl_/2

  % pipe i/o interface
  ,call/2
  ,call/3
  ,pcall/3
  ,pcall/4
  ,cast/2
  ,cast/3
  ,pcast/2
  ,pcast/3
  ,send/2
  ,send/3
  ,psend/2
  ,psend/3
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
  ,uref/1 
  ,behaviour_info/1
]).

-export_type([pipe/0]).

-type(pipe() :: {pipe, proc(), proc()}).
-type(proc() :: atom() | {atom(), atom()} | {global, atom()} | pid() | function()).
-type(name() :: {local, atom()} | {global, atom()}).
-type(tx()   :: {pid(), reference()} | {reference(), pid()} | pid()).

%% process monitor
-type(monitor() :: {reference(), pid() | node()}).

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
%% start pipe stage / pipe state machine
-spec(start/3 :: (atom(), list(), list()) -> {ok, pid()} | {error, any()}).
-spec(start/4 :: (name(), atom(), list(), list()) -> {ok, pid()} | {error, any()}).
-spec(start_link/3 :: (atom(), list(), list()) -> {ok, pid()} | {error, any()}).
-spec(start_link/4 :: (name(), atom(), list(), list()) -> {ok, pid()} | {error, any()}).

start(Mod, Args, Opts) ->
   gen_server:start(?CONFIG_PIPE, [Mod, Args, Opts], Opts).
start(Name, Mod, Args, Opts) ->
   gen_server:start(Name, ?CONFIG_PIPE, [Mod, Args, Opts], Opts).

start_link(Mod, Args, Opts) ->
   gen_server:start_link(?CONFIG_PIPE, [Mod, Args, Opts], Opts).
start_link(Name, Mod, Args, Opts) ->
   gen_server:start_link(Name, ?CONFIG_PIPE, [Mod, Args, Opts], Opts).

%%
%% spawn pipe functor stage
%% @todo spawn_opt
-spec(spawn/1         :: (function()) -> pid()).
-spec(spawn_link/1    :: (function()) -> pid()).
-spec(spawn_monitor/1 :: (function()) -> {pid(), reference()}).

spawn(Fun) ->
   erlang:spawn(fun() -> loop(Fun) end).

spawn_link(Fun) ->
   erlang:spawn_link(fun() -> loop(Fun) end).

spawn_monitor(Fun) ->
   erlang:spawn_monitor(fun() -> loop(Fun) end).

%%
%% pipe loop
-spec(loop/1 :: (function()) -> any()).

loop(Fun) ->
   pipe_loop(Fun, undefined, undefined).


%%
%% bind process to pipeline
-spec(bind/2 :: (a | b, pid()) -> {ok, pid()}).
-spec(bind/3 :: (a | b, pid(), pid()) -> {ok, pid()}).

bind(a, Pids)
 when is_list(Pids) ->
   bind(a, hd(Pids));
bind(b, Pids)
 when is_list(Pids) ->
   bind(a, lists:last(Pids));

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
-spec(make/1 :: ([proc()]) -> pid()).

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
   ).

%%
%% terminate pipeline
-spec(free/1 :: (pid() | [proc()]) -> ok).

free(Pid)
 when is_pid(Pid) ->
   erlang:send(Pid, {'$pipe', self(), '$free'}),
   ok;
free({Pid, Ref})
 when is_pid(Pid) ->
   _ = erlang:demonitor(Ref, [flush]),
   erlang:send(Pid, {'$pipe', self(), '$free'}),
   ok;
free(Pipeline)
 when is_list(Pipeline) ->
   lists:foreach(fun free/1, Pipeline).

%%
%% ioctl interface (sync and async)
-spec(ioctl/2  :: (proc(), atom() | {atom(), any()}) -> any()).
-spec(ioctl_/2 :: (proc(), atom() | {atom(), any()}) -> any()).

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


%%
%% make synchronous request to process
-spec(call/2 :: (proc(), any()) -> any()).
-spec(call/3 :: (proc(), any(), timeout()) -> any()).

call(Pid, Msg) ->
   call(Pid, Msg, ?CONFIG_TIMEOUT).
call(Pid, Msg, Timeout) ->
   %% @todo: fix node monitor, lookup only process node
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
%% make synchronous request in parallel to process(es)
-spec(pcall/3 :: (pid(), [proc()], any()) -> any()).
-spec(pcall/4 :: (pid(), [proc()], any(), timeout()) -> any()).

pcall(Fsm, Pids, Req) ->
   pcall(Fsm, Pids, Req, ?CONFIG_TIMEOUT).

pcall(_Fsm, [], _Req, _Timeout) ->
   {[], []};
pcall(Fsm, Pids, Req,  Timeout) ->
   pipe:call(Fsm, {pcall, Pids, Req, Timeout}, infinity).


%%
%% cast asynchronous request to process
%%   Options:
%%      yield     - suspend current processes
%%      noconnect - do not connect to remote node
%%      flow      - use flow control
-spec(cast/2 :: (proc(), any()) -> reference()).
-spec(cast/3 :: (proc(), any(), list()) -> reference()).

cast(Pid, Msg) ->
   cast(Pid, Msg, []).

cast(Pid, Msg, Opts) ->
   Tx = erlang:make_ref(),
   pipe_send(Pid, {Tx, self()}, Msg, io_flags(Opts)),
   Tx.

%%
%% cast asynchronous request in parallel to processes
%%   Options:
%%      yield     - suspend current processes
%%      noconnect - do not connect to remote node
%%      flow      - use flow control
-spec(pcast/2 :: ([proc()], any()) -> [{reference(), pid()}]).
-spec(pcast/3 :: ([proc()], any(), list()) -> [{reference(), pid()}]).

pcast(Pids, Msg) ->
   pcast(Pids, Msg, []).

pcast(Pids, Msg, Opts) ->
   [{cast(Pid, Msg, Opts), Pid} || Pid <- Pids].

%%
%% send asynchronous request to process 
%%   Options:
%%      yield     - suspend current processes
%%      noconnect - do not connect to remote node
%%      flow      - use flow control
-spec(send/2 :: (proc(), any()) -> any()).
-spec(send/3 :: (proc(), any(), list()) -> any()).

send(Pid, Msg) ->
   send(Pid, Msg, []).
send(Pid, Msg, Opts) ->
   pipe_send(Pid, self(), Msg, io_flags(Opts)).


%%
%% send asynchronous request in parallel to process 
%%   Options:
%%      yield     - suspend current processes
%%      noconnect - do not connect to remote node
%%      flow      - use flow control
-spec(psend/2 :: ([proc()], any()) -> [reference()]).
-spec(psend/3 :: ([proc()], any(), list()) -> [reference()]).

psend(Pids, Msg) ->
   psend(Pids, Msg, []).

psend(Pids, Msg, Opts) ->
   lists:foreach(
      fun(Pid) -> send(Pid, Msg, Opts) end,
      Pids
   ),
   Msg.


%%
%% send message through pipe
%%   Options:
%%      yield     - suspend current processes
%%      noconnect - do not connect to remote node
%%      flow      - use flow control
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
ack({'$flow', {_, Pid}}) ->
   pipe_flow:produce(Pid);  
ack({'$flow', Pid}) ->
   pipe_flow:produce(Pid);   
ack(_) ->
   ok.

ack({pipe, A, _}, Msg) ->
   ack(A, Msg);
ack({'$flow', {_, Pid}=Tx}, Msg) ->
   pipe_flow:produce(Pid),
   ack(Tx, Msg);
ack({'$flow', Pid}, Msg) ->
   pipe_flow:produce(Pid),
   ack(Pid, Msg);
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
      Msg;
   {'$flow', Pid, D} ->
      pipe_flow:credit(Pid, D),
      recv(Timeout, Opts)
   after Timeout ->
      recv_error(Opts, timeout)
   end.

recv(Pid, Timeout, Opts) ->
   %% @todo: fix node monitor, lookup only process node
   Ref  = {_, Tx, _} = pipe:monitor(process, Pid),
   receive
   {'$pipe', Pid, Msg} ->
      pipe:demonitor(Ref),
      Msg;
   {'$flow', Any, D} ->
      pipe:demonitor(Ref),
      pipe_flow:credit(Any, D),
      recv(Pid, Timeout, Opts);
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

%%
%% universal transaction reference (external use)
-spec(uref/1 :: (pipe()) -> binary()).

uref(Pipe) ->
   Tx   = erlang:term_to_binary({pipe:pid(Pipe), pipe:tx(Pipe)}),
   case erlang:function_exported(crypto, hash, 2) of
      true  -> btoh( crypto:hash(sha, Tx) );
      false -> btoh( crypto:sha(Tx) )
   end.

btoh(X) ->
   << <<(if A < 10 -> $0 + A; A >= 10 -> $a + (A - 10) end):8>> || <<A:4>> <=X >>.

%%%----------------------------------------------------------------------------   
%%%
%%% private
%%%
%%%----------------------------------------------------------------------------   

%%
%% send message through pipe
%% @todo: iterate flags and do commands (no need to integer convert)
pipe_send(Pid, Tx, Msg, Flags)
 when is_pid(Pid) ->
   try
      case Flags band ?IO_FLOW of
         0 ->
            pipe_send_msg(Pid, {'$pipe', Tx, Msg}, Flags band ?IO_NOCONNECT),
            pipe_yield(Flags band ?IO_YIELD);
         _ ->
            pipe_send_msg(Pid, {'$pipe', {'$flow', Tx}, Msg}, Flags band ?IO_NOCONNECT),
            pipe_yield(Flags band ?IO_YIELD),
            pipe_flow:consume(Pid)
      end,
      Msg
   catch error:_ ->
      Msg
   end;
pipe_send(Fun, Tx, Msg, Flags)
 when is_function(Fun) ->
   pipe_send(Fun(Msg), Tx, Msg, Flags);
pipe_send(undefined, _Tx, Msg, _Flags) ->
   Msg;
pipe_send(Name, Tx, Msg, Flags)
 when is_atom(Name) ->
   pipe_send(erlang:whereis(Name), Tx, Msg, Flags).


%%
%% send message to pipe process
pipe_send_msg(Pid, Msg, 0) ->
   erlang:send(Pid, Msg, []);
pipe_send_msg(Pid, Msg, _) ->
   erlang:send(Pid, Msg, [noconnect]).

%%
%% yield current process
pipe_yield(0) -> ok;
pipe_yield(_) -> erlang:yield().


%%
%% send options
io_flags(Flags) ->
   io_flags(Flags, 0).
io_flags([yield  |T], Flags) ->
   io_flags(T, ?IO_YIELD bor Flags);
io_flags([noconnect|T], Flags) ->
   io_flags(T, ?IO_NOCONNECT bor Flags);
io_flags([flow   |T], Flags) ->
   io_flags(T, ?IO_FLOW bor Flags);
io_flags([_|T], Flags) ->
   io_flags(T, Flags);
io_flags([], Flags) ->
   Flags.

%%
%% pipe loop
pipe_loop(Fun, A, B) ->
   receive
   %% binding
   {'$pipe', _Tx, {ioctl, a, Pid}} ->
      ?DEBUG("pipe ~p: bind a to ~p", [self(), Pid]),
      pipe_loop(Fun, Pid, B);
   {'$pipe', Tx, {ioctl, a}} ->
      ack(Tx, {ok, A}),
      pipe_loop(Fun, A, B);
   {'$pipe', _Tx, {ioctl, b, Pid}} ->
      ?DEBUG("pipe ~p: bind b to ~p", [self(), Pid]),
      pipe_loop(Fun, A, Pid);
   {'$pipe', Tx, {ioctl, b}} ->
      ack(Tx, {ok, B}),
      pipe_loop(Fun, A, B);
   {'$pipe', Tx, {ioctl, _, _}} ->
      ack(Tx, {error, not_supported}),
      pipe_loop(Fun, A, B);
   {'$pipe', _Pid, '$free'} ->
      ?DEBUG("pipe ~p: free by ~p", [self(), Pid]),
      ok;
   {'$flow', Pid, D} ->
      pipe_flow:credit(Pid, D),
      pipe_loop(Fun, A, B);
   {'$pipe', Tx, Msg} when Tx =:= B orelse B =:= undefined ->
      maybe_send(A, Fun(Msg)),
      pipe:ack(Tx),
      pipe_loop(Fun, A, B);
   {'$pipe', {'$flow', Tx}, Msg} when Tx =:= B ->
      maybe_send(A, Fun(Msg)),
      pipe:ack(Tx),
      pipe_loop(Fun, A, B);
   {'$pipe', Tx, Msg} ->
      maybe_send(B, Fun(Msg)),
      pipe:ack(Tx),
      pipe_loop(Fun, A, B)
   end.

maybe_send(_Pid, undefined) ->
   ok;
maybe_send(Pid,  Msg) ->
   pipe:send(Pid, Msg).

