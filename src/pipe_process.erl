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
%%    pipe process container
%%
%% @todo
%%    use proc_lib:spawn_link or proc_lib:start_link to start the process
%%    then perform your initialization (calling proc_lib:init_ack where appropriate), 
%%    and finally calling gen_server:enter_loop. What this gives you is pretty much 
%%    the ability to customize the initialization of your gen_server process.
-module(pipe_process).
-behaviour(gen_server).
-include("pipe.hrl").

-export([
   init/1, 
   terminate/2,
   handle_call/3,
   handle_cast/2,
   handle_info/2,
   code_change/3
]).

%% internal state
-record(machine, {
   mod       = undefined :: atom()  %% FSM implementation
  ,sid       = undefined :: atom()  %% FSM state (transition function)
  ,state     = undefined :: any()   %% FSM internal data structure
  ,a         = undefined :: pid()   %% pipe side (a) // source
  ,b         = undefined :: pid()   %% pipe side (b) // sink
}).

%%%----------------------------------------------------------------------------   
%%%
%%% Factory
%%%
%%%----------------------------------------------------------------------------   

%%
%%
init([Mod, Args]) ->
   init(Mod:init(Args), #machine{mod=Mod}).

init({ok, Sid, State}, S) ->
   {ok, S#machine{sid=Sid, state=State}};
init({error,  Reason}, _) ->
   {stop, Reason}.   

%%
%%
terminate(Reason, #machine{mod=Mod, state=State}) ->
   Mod:free(Reason, State).
   
%%%----------------------------------------------------------------------------   
%%%
%%% gen_server
%%%
%%%----------------------------------------------------------------------------   

%%
%%
handle_call(Msg, Tx, #machine{}=S) ->
   % synchronous out-of-bound call to machine   
   ?DEBUG("pipe call ~p: tx ~p, msg ~p~n", [self(), Tx, Msg]),
   run(Msg, make_pipe(Tx, S#machine.a, S#machine.b), S).

%%
%%
handle_cast(_, S) ->
   {noreply, S}.

%%
%%
handle_info({'$pipe', _Tx, {ioctl, a, Pid}}, S) ->
   ?DEBUG("pipe ~p: bind a to ~p", [self(), Pid]),
   pipe:monitor(Pid),
   {noreply, S#machine{a=Pid}};

handle_info({'$pipe', Tx, {ioctl, a}}, S) ->
   pipe:ack(Tx, {ok, S#machine.a}),
   {noreply, S};

handle_info({'$pipe', _Tx, {ioctl, b, Pid}}, S) ->
   ?DEBUG("pipe ~p: bind b to ~p", [self(), Pid]),
   pipe:monitor(Pid),
   {noreply, S#machine{b=Pid}};

handle_info({'$pipe', Tx, {ioctl, b}}, S) ->
   pipe:ack(Tx, {ok, S#machine.b}),
   {noreply, S};

handle_info({'$pipe', Tx, {ioctl, Req, Val}}, #machine{mod=Mod}=S) ->
   % ioctl set request
   ?DEBUG("pipe ioctl ~p: req ~p, val ~p~n", [self(), Req, Val]),
   try
      State = Mod:ioctl({Req, Val}, S#machine.state),
      pipe:ack(Tx, ok),
      {noreply, S#machine{state = State}}
   catch _:_ ->
      pipe:ack(Tx, ok),
      {noreply, S}
   end;

handle_info({'$pipe', Tx, {ioctl, Req}}, #machine{mod=Mod}=S) ->
   % ioctl get request
   ?DEBUG("pipe ioctl ~p: req ~p~n", [self(), Req]),
   try
      pipe:ack(Tx, Mod:ioctl(Req, S#machine.state)),
      {noreply, S}
   catch _:_ ->
      pipe:ack(Tx, undefined),
      {noreply, S}
   end;

%%   
%%   
handle_info({'DOWN', _Ref, process, A, Reason}, #machine{a = A, b = B}=State) ->
   case erlang:process_info(self(), trap_exit) of
      {trap_exit, false} ->
         {stop, normal, State};
      {trap_exit,  true} ->
         run({sidedown, a, Reason}, {pipe, B, undefined}, State)
   end;
handle_info({'DOWN', _Ref, process, B, Reason}, #machine{a = A, b = B}=State) ->
   case erlang:process_info(self(), trap_exit) of
      {trap_exit, false} ->
         {stop, normal, State};
      {trap_exit,  true} ->
         run({sidedown, b, Reason}, {pipe, A, undefined}, State)
   end;

handle_info({'$pipe', _Pid, '$free'}, State) ->
   case erlang:process_info(self(), trap_exit) of
      {trap_exit, false} ->
         {stop, normal, State};
      {trap_exit,  true} ->
         {noreply, State}
   end;

handle_info({'$pipe', Tx, Msg}, #machine{a = A, b = B}=State) ->   
   %% in-bound call to FSM
   ?DEBUG("pipe recv ~p: tx ~p, msg ~p~n", [self(), Tx, Msg]),
   run(Msg, make_pipe(Tx, A, B), State);

handle_info(Msg, #machine{a = A, b = B}=State) ->
   %% out-of-bound message, assume b is emitter, a is consumer
   ?DEBUG("pipe recv ~p: msg ~p~n", [self(), Msg]),
   run(Msg, {pipe, B, A}, State).

%%
%%
code_change(_Vsn, S, _) ->
   {ok, S}.

%%%----------------------------------------------------------------------------   
%%%
%%% private
%%%
%%%----------------------------------------------------------------------------   

%%
%% make pipe object for side-effect
make_pipe(Tx, A, B)
 when Tx =:= A ->
   {pipe, A, B};
make_pipe(Tx, A, B)
 when Tx =:= B ->
   {pipe, B, A};
make_pipe(Tx, A, B)
 when Tx =:= self() ->
   {pipe, A, B};
make_pipe(Tx, undefined, B) ->
   {pipe, Tx, B};
make_pipe(Tx, A, _B) ->
   {pipe, Tx, A}.

%%
%% run state machine
run(Msg, Pipe, #machine{mod=Mod, sid=Sid0}=S) ->
   case Mod:Sid0(Msg, Pipe, S#machine.state) of
      {next_state, Sid, State} ->
         {noreply, S#machine{sid=Sid, state=State}};

      {next_state, Sid, State, TorH} ->
         {noreply, S#machine{sid=Sid, state=State}, TorH};

      {upgrade, New, Args} ->
         case New:init(Args) of
            {ok, Sid, State}  ->
               {noreply, S#machine{mod=New, sid=Sid, state=State}};
            {error, Reason} ->
               {stop, Reason, S}
         end;

      {stop, Reason, State} ->
         {stop, Reason, S#machine{state=State}}
   end.

