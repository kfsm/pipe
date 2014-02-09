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
   % pipe / state / pipeline management api
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
   % 
   monitor/1
  ,demonitor/1
  ,flag/2
  ,call/2
  ,call/3
  ,cast/2
  ,cast/3
  ,send/2
  ,send/3
  ,ack/1
  ,ack/2


  ,a/1,
   a/2, 
   a/3,
   b/1,
   b/2,
   b/3, 
   relay/2,
   relay/3,
   recv/0, 
   recv/1,
   recv/2,
   recv/3,
   ioctl/2,
   stream/1,
   stream/2,
   behaviour_info/1
]).

-export_type([pipe/0]).

-type(pipe() :: {pipe, proc(), proc()}).
-type(proc() :: atom() | {atom(), atom()} | {global, atom()} | pid() | function()).
-type(name() :: {local, atom()} | {global, atom()}).

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
   gen_server:start(?CONFIG_PIPE, [Mod, Args], Opts).
start(Name, Mod, Args, Opts) ->
   gen_server:start(Name, ?CONFIG_PIPE, [Mod, Args], Opts).

start_link(Mod, Args, Opts) ->
   gen_server:start_link(?CONFIG_PIPE, [Mod, Args], Opts).
start_link(Name, Mod, Args, Opts) ->
   gen_server:start_link(Name, ?CONFIG_PIPE, [Mod, Args], Opts).

%%
%% spawn pipe functor stage
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
-spec(bind/2 :: (a | b, pid()) -> {ok, pid()}).
-spec(bind/3 :: (a | b, pid(), pid()) -> {ok, pid()}).

bind(a, Pids)
 when is_list(Pids) ->
   bind(a, hd(Pids));
bind(b, Pids)
 when is_list(Pids) ->
   bind(a, lists:last(Pids));

bind(a, Pid) ->
   ioctl(Pid, {a, self()});
bind(b, Pid) ->
   ioctl(Pid, {b, self()}).

bind(a, Pids, A)
 when is_list(Pids) ->
   bind(a, hd(Pids), A);
bind(a, Pids, A)
 when is_list(Pids) ->
   bind(a, lists:last(Pids), A);

bind(a, Pid, A) ->
   ioctl(Pid, {a, A});
bind(b, Pid, B) ->
   ioctl(Pid, {b, B}).

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
%% return pid() of pipe processes
-spec(a/1 :: (pipe()) -> pid()).
-spec(b/1 :: (pipe()) -> pid()).

a({pipe, A, _}) -> 
   A.
b({pipe, _, B}) -> 
   B.

%%
%% monitor process or node. The process receives messages:
%%   {'DOWN', monitor(), process, pid(), reason()}
%%   {nodedown, monitor()}
-spec(monitor/1 :: (pid()) -> monitor()).

monitor(Pid)
 when is_pid(Pid) ->
   try erlang:monitor(process, Pid) of
      Ref ->
         {Ref, Pid}
   catch error:_ ->
      % unable to set monitor, fall-back to node monitor
      monitor(erlang:node(Pid))
   end;

monitor(Node)
 when is_atom(Node) ->
   monitor_node(Node, true),
   receive
      {nodedown, Node} -> 
         monitor_node(Node, false),
         exit({nodedown, Node})
   after 0 -> 
      {erlang:make_ref(), Node}
   end.
 
%%
%% release process monitor
-spec(demonitor/1 :: (monitor()) -> ok).

demonitor({Ref, Pid})
 when is_pid(Pid) ->
   erlang:demonitor(Ref, [flush]);

demonitor({_, Node})
 when is_atom(Node) ->
   monitor_node(Node, false),
   receive
      {nodedown, Node} -> 
         ok
   after 0 ->
      ok 
   end.

%%
%% set pipe flag(s) @todo - rename to ioctl
-spec(flag/2 :: (atom(), any()) -> ok).

flag(credit, Value) ->
   put({credit, default}, Value).



%%
%% make synchronous request to process
-spec(call/2 :: (proc(), any()) -> any()).
-spec(call/3 :: (proc(), any(), timeout()) -> any()).

call(Pid, Msg) ->
   call(Pid, Msg, ?CONFIG_TIMEOUT).
call(Pid, Msg, Timeout) ->
   Ref = {Tx, _} = pipe:monitor(Pid),
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
%%      flow      - use flow control
-spec(cast/2 :: (proc(), any()) -> reference()).
-spec(cast/3 :: (proc(), any(), list()) -> reference()).

cast(Pid, Msg) ->
   cast(Pid, Msg, []).

cast(Pid, Msg, Opts) ->
   Tx    = erlang:make_ref(),
   pipe_send(Pid, {Tx, self()}, Msg, io_flags(Opts)),
   Tx.

%%
%% send asynchronous request to process 
%%   Options:
%%      yield     - suspend current processes
%%      noconnect - do not connect to remote node
%%      flow      - use flow control
-spec(send/2 :: (proc(), any()) -> reference()).
-spec(send/3 :: (proc(), any(), list()) -> reference()).

send(Pid, Msg) ->
   send(Pid, Msg, []).

send(Pid, Msg, Opts) ->
   pipe_send(Pid, self(), Msg, io_flags(Opts)).

%%
%% acknowledge message
-spec(ack/1 :: (pid()) -> ok).

ack({pipe, A, _}) ->
   ack(A);
ack(Pid) ->
   ok.
 % when is_pid(Pid) ->
 %   ?FLOW_CTL(Pid, ?DEFAULT_DEBIT, C,
 %      if C == 1 -> 
 %            erlang:send(Pid, {'$pipe', '$debit', self(), ?DEFAULT_DEBIT}),
 %            ?DEFAULT_DEBIT;
 %         true   -> 
 %            C - 1
 %      end
 %   ),
 %   ok.

ack({Pid, Ref}, Msg)
 when is_pid(Pid), is_reference(Ref) ->
   erlang:send(Pid, {Ref, Msg}).



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

a({pipe, A, _}, Msg) -> ok.
   %do_send(A, self(), Msg, 0).
a({pipe, A, _}, Msg, Opts) -> ok.
%   do_send(A, self(), Msg, Opts).

b({pipe, _, B}, Msg) -> ok.
%   do_send(B, self(), Msg, 0).
b({pipe, _, B}, Msg, Opts) -> ok.
%   do_send(B, self(), Msg, Opts).

% %%
% %% send pipe message to process 
% -spec(send/2 :: (proc(), any()) -> any()).
% -spec(send/3 :: (proc(), any(), list()) -> any()).

% send(_, undefined) ->
%    ok;
% send(Sink, Msg) ->
%    do_send(Sink, self(), Msg, 0).

% send(_, undefined, _Opts) ->
%    ok;
% send(Sink, Msg, Opts) ->
%    do_send(Sink, self(), Msg, io_flags(Opts, 0)).

%%
%% relay pipe message
%%    Options:
%%       yield   - suspend current processes
%%       connect - connect remote node
%%       flow    - use flow control
-spec(relay/2 :: (pipe(), any()) -> any()).
-spec(relay/3 :: (pipe(), any(), list()) -> any()).

relay({pipe, A, B}, Msg) -> ok.
%   do_send(B, A, Msg, 0).

relay({pipe, A, B}, Msg, Opts) -> ok.
%   do_send(B, A, Msg, io_flags(Opts, 0)).

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
   call(Pid, {ioctl, Req, Val});
ioctl(Pid, Req)
 when is_atom(Req) ->
   call(Pid, {ioctl, Req}).

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
%% send message through pipe
pipe_send(Pid, Tx, Msg, Flags)
 when is_pid(Pid) ->
   try
      pipe_send_msg(Pid, {'$pipe', Tx, Msg}, Flags band ?IO_NOCONNECT),
      pipe_yield(Flags band ?IO_YIELD),
      pipe_flow_ctrl(Pid, Flags band ?IO_FLOW),
      Msg
   catch error:_ ->
      Msg
   end;

pipe_send(Fun, Tx, Msg, Flags)
 when is_function(Fun) ->
   pipe_send(Fun(Msg), Tx, Msg, Flags);
pipe_send(Name, Tx, Msg, Flags)
 when is_atom(Name) ->
   pipe_send(erlang:whereis(Name), Tx, Msg, Flags);
pipe_send(undefined, _Tx, Msg, _Flags) ->
   Msg.


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
%% flow control
pipe_flow_ctrl(_Pid, 0) ->
   ok;
pipe_flow_ctrl(Pid,  _) ->
   % @todo do not use credit if destination itself
   credit_withdraw(Pid).


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
   {'$pipe', Tx, {ioctl, a, Pid}} ->
      ?DEBUG("pipe ~p: bind a to ~p", [self(), Pid]),
      ack(Tx, {ok, A}),
      pipe_loop(Fun, Pid, B);
   {'$pipe', Tx, {ioctl, a}} ->
      ack(Tx, {ok, A}),
      pipe_loop(Fun, A, B);
   {'$pipe', Tx, {ioctl, b, Pid}} ->
      ?DEBUG("pipe ~p: bind b to ~p", [self(), Pid]),
      ack(Tx, {ok, B}),
      pipe_loop(Fun, A, Pid);
   {'$pipe', Tx, {ioctl, b}} ->
      ack(Tx, {ok, B}),
      pipe_loop(Fun, A, B);

   {'$pipe', Pid, '$free'} ->
      ?DEBUG("pipe ~p: free by ~p", [self(), Pid]),
      ok;

   % {'$pipe', '$debit', Pid, D} ->
   %    ?FLOW_CTL(Pid, ?DEFAULT_CREDIT, C,
   %       erlang:min(?DEFAULT_CREDIT, C + D)
   %    ),
   %    pipe_loop(Fun, A, B);
   {'$pipe', B, Msg} ->
      _ = pipe:send(A, Fun(Msg)),
      pipe_loop(Fun, A, B);
   {'$pipe', _, Msg} ->
      _ = pipe:send(B, Fun(Msg)),
      %pipe:ack(S),
      pipe_loop(Fun, A, B)
   end.



%%
%% get credit value
credit_amount(Pid) ->
   case get({credit, Pid}) of
      undefined ->
         case get({credit, default}) of
            undefined -> ?DEFAULT_CREDIT;
            X         -> X
         end;
      X ->
         X
   end.

%%
%% consume credit
credit_withdraw(Pid) ->
   case credit_amount(Pid) of
      1 -> put({credit, Pid}, credit_recv(Pid));
      X -> put({credit, Pid}, X - 1)
   end. 


%%
%% receive credit from recipient process
credit_recv(Pid) ->
   Ref = {Tx, _} = pipe:monitor(Pid),
   receive
      {'$pipe', Pid, {credit, Credit}} ->
         pipe:demonitor(Ref),
         Credit;
      {'DOWN', Tx, _, _, noconnection} ->
         pipe:demonitor(Ref),
         exit({nodedown, erlang:node(Pid)});
      {'DOWN', Tx, _, _, Reason} ->
         pipe:demonitor(Ref),
         exit(Reason);
      {nodedown, Node} ->
         pipe:demonitor(Ref),
         exit({nodedown, Node})
   % after Timeout ->
   %    pipe:demonitor(Ref),
   %    exit(timeout)
   end.   

