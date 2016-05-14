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
  ,spawn_link/2
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

%%%------------------------------------------------------------------
%%%
%%% data types
%%%
%%%------------------------------------------------------------------   
-export_type([pipe/0, f/0]).

%%
%% The pipe descriptor is opaque structure maintained by pipe process.
%% The description is used by state machine behavior to emit messages.
-type pipe()  :: {pipe, a(), b()}.
-type a()     :: pid() | tx().
-type b()     :: pid().
-type tx()    :: {pid(), reference()} | {reference(), pid()}.

%%
%% Pipe lambda expression is spawned within pipe process.
%% It builds a new message by applying a function to all received message.
%% The process emits the new message either to side (a) or (b). 
-type f() :: fun((_) -> {a, _} | {b, _} | _).

%%
%% the process monitor structure 
-type monitor() :: {reference(), pid() | node()}.


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
      %% -spec(init/1 :: ([_]) -> {ok, sid(), state()} | {stop, any()}).
      {init,  1}
   
      %%
      %% free pipe stage
      %%
      %% -spec(free/2 :: (_, state()) -> ok).
     ,{free,  2}

      %%
      %% state machine i/o control interface (optional)
      %%
      %% -spec(ioctl/2 :: (atom() | {atom(), _}, state()) -> _ | state()).       
      %%,{ioctl, 2}

      %%
      %% state message handler
      %%
      %% -spec(handle/3 :: (_, pipe(), state()) -> {next_state, sid(), state()} 
      %%                                           |  {stop, _, state()} 
      %%                                           |  {upgrade, atom(), [_]}). 
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
%% start pipe state machine, the function takes behavior module,
%% list of arguments to pipe init functions and list of container options.
-spec(start/3 :: (atom(), [_], [_]) -> {ok, pid()} | {error, any()}).
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
%% spawn pipe lambda expression
%% function is fun/1 :: (any()) -> {a, Msg} | {b, Msg}
-spec(spawn/1         :: (f()) -> pid()).
-spec(spawn_link/1    :: (f()) -> pid()).
-spec(spawn_link/2    :: (f(), list()) -> pid()).

spawn(Fun) ->
   {ok, Pid} = start(pipe_funct, [Fun], []),
   Pid.

spawn_link(Fun) ->
   pipe:spawn_link(Fun, []).

spawn_link(Fun, Opts0) ->
   {ok, Pid} = case lists:keytake(init, 1, Opts0) of
      false ->
         start_link(pipe_funct, [Fun], Opts0);
      {value, {init, Init}, Opts1} ->
         % @todo: check usability of init option
         start_link(pipe_funct, [Init, Fun], Opts1)
   end,
   Pid.

%%
%% terminate pipe or pipeline
-spec(free/1 :: (pid() | [pid()]) -> ok).

free(Pid)
 when is_pid(Pid) ->
   erlang:send(Pid, {'$pipe', self(), '$free'}),
   ok;
free(Pipeline)
 when is_list(Pipeline) ->
   lists:foreach(fun free/1, Pipeline).


%%
%% bind stage(s) together defining processing pipeline
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
%% The helper function to monitor either Erlang process or Erlang node. 
%% The caller process receives one of following messages:
%%   {'DOWN', reference(), process, pid(), reason()}
%%   {nodedown, node()}
-spec(monitor/1 :: (pid()) -> monitor()).
-spec(monitor/2 :: (atom(), pid()) -> monitor()).

monitor(undefined) ->
   ok;
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
   erlang:monitor_node(Node, true),
   {node, erlang:make_ref(), Node}.
 
%%
%% release process monitor
-spec(demonitor/1 :: (monitor()) -> ok).

demonitor({process, Ref, _Pid}) ->
   erlang:demonitor(Ref, [flush]);

demonitor({node, _, Node}) ->
   erlang:monitor_node(Node, false),
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
%% make synchronous request to pipe.
%% the caller process is blocked until response is received.
-spec(call/2 :: (pid(), _) -> _).
-spec(call/3 :: (pid(), _, timeout()) -> _).

call(Pid, Msg) ->
   call(Pid, Msg, ?CONFIG_TIMEOUT).
call(Pid, Msg, Timeout) ->
   try erlang:monitor(process, Pid) of
      Tx ->
         catch erlang:send(Pid, {'$pipe', {self(), Tx}, Msg}, [noconnect]),
         receive
         {Tx, Reply} ->
            erlang:demonitor(Tx, [flush]),
            Reply;
         {'DOWN', Tx, _, _, noconnection} ->
            exit({nodedown, erlang:node(Pid)});
         {'DOWN', Tx, _, _, Reason} ->
            exit(Reason)
         after Timeout ->
            erlang:demonitor(Tx, [flush]),
            exit(timeout)
         end
   catch error:_ ->
      Tx   = erlang:make_ref(),
      Node = erlang:node(Pid),
      monitor_node(Node, true),
      catch erlang:send(Pid, {'$pipe', {self(), Tx}, Msg}, [noconnect]),
      receive
      {Tx, Reply} ->
         monitor_node(Node, false),
         Reply;
      {nodedown, Node} ->
         exit({nodedown, Node})
      after Timeout ->
         monitor_node(Node, false),
         exit(timeout)
      end
   end.

%%
%% cast asynchronous request to process
%%   Options:
%%      yield     - suspend current processes
%%      noconnect - do not connect to remote node
-spec(cast/2 :: (pid(), _) -> reference()).
-spec(cast/3 :: (pid(), _, [atom()]) -> reference()).

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
-spec(send/2 :: (pid(), _) -> _).
-spec(send/3 :: (pid(), _, [atom()]) -> _).

send(Pid, Msg) ->
   send(Pid, Msg, []).
send(Pid, Msg, Opts) ->
   pipe_send(Pid, self(), Msg, Opts).

%%
%% forward asynchronous request to destination pipe.
%% the side (a) is preserved and forwarded to destination pipe  
-spec(emit/3 :: (pipe(), pid(), _) -> _).
-spec(emit/4 :: (pipe(), pid(), _, [atom()]) -> _).

emit(Pipe, Pid, Msg) ->
   emit(Pipe, Pid, Msg, []).

emit({pipe, A, _}, Pid, Msg, Opts) ->
   pipe_send(Pid, A, Msg, Opts).

%%
%% send message through pipe either to side (a) or (b)
%%   Options:
%%      yield     - suspend current processes
%%      noconnect - do not connect to remote node
-spec(a/2 :: (pipe(), _) -> ok).
-spec(a/3 :: (pipe(), _, [atom()]) -> ok).
-spec(b/2 :: (pipe(), _) -> ok).
-spec(b/3 :: (pipe(), _, [atom()]) -> ok).

a({pipe, Pid, _}, Msg)
 when is_pid(Pid) orelse is_atom(Pid) ->
   pipe:send(Pid, Msg);
a({pipe, {Pid, Tx}, _}, Msg)
 when is_pid(Pid), is_reference(Tx) ->
   % backward compatible with gen_server:reply
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
%% acknowledge message received at pipe side (a)
-spec(ack/2 :: (pipe() | tx(), any()) -> any()).

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
 when is_pid(Pid) ->
   % no acknowledgment send for transactions originated by send 
   Msg;
ack(_, Msg) ->
   Msg.

%%
%% receive message from pipe (match-only pipe protocol)
%%  Options
%%    noexit - opts returns {error, timeout} instead of exit signal
-spec(recv/0 :: () -> _).
-spec(recv/1 :: (timeout()) -> _).
-spec(recv/2 :: (timeout(), [atom()]) -> _).
-spec(recv/3 :: (pid(), timeout(), [atom()]) -> _).

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
   {'$pipe',   _, {ioctl, _, Pid} = Msg} ->
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





