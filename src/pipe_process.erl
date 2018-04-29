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
   mod       = undefined :: atom(),    %% FSM implementation
   sid       = undefined :: atom(),    %% FSM state (transition function)
   state     = undefined :: any(),     %% FSM internal data structure
   a         = undefined :: pid(),     %% pipe side (a) // source
   b         = undefined :: pid(),     %% pipe side (b) // sink
   acapacity = undefined :: integer(), %% pipe own capacity to forward a message
   bcapacity = undefined :: integer(), %% pipe own capacity to forward a message
   acredit   = undefined :: integer(), %% pipe available credits to forward message 
   bcredit   = undefined :: integer()  %% pipe available credits to forward message 
}).

%%%----------------------------------------------------------------------------   
%%%
%%% Factory
%%%
%%%----------------------------------------------------------------------------   

%%
%%
init([Mod, Args, Opts]) ->
   init(Mod:init(Args), 
      #machine{
         mod       = Mod,
         acapacity = option(acapacity, Opts),
         bcapacity = option(bcapacity, Opts)
      }
   ).

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
handle_call(Msg, Tx, #machine{} = S) ->
   % synchronous out-of-bound call to machine   
   ?DEBUG("pipe call ~p: tx ~p, msg ~p~n", [self(), Tx, Msg]),
   run(Msg, make_pipe(Tx, S#machine.a, S#machine.b), S).

%%
%%
handle_cast(_, State) ->
   {noreply, State}.

%%
%%
handle_info({'$pipe', _Tx, {ioctl, a, Pid}}, #machine{acapacity = undefined} = State) ->
   ?DEBUG("pipe ~p: bind a to ~p", [self(), Pid]),
   pipe:monitor(Pid),
   {noreply, State#machine{a = Pid}};

handle_info({'$pipe', _Tx, {ioctl, a, Pid}}, #machine{acapacity = N} = State) ->
   ?DEBUG("pipe ~p: bind a to ~p", [self(), Pid]),
   pipe:monitor(Pid),
   pipe:ioctl_(Pid, {bcredit, N}),
   {noreply, State#machine{a = Pid}};

handle_info({'$pipe', Tx, {ioctl, a}}, S) ->
   pipe:ack(Tx, {ok, S#machine.a}),
   {noreply, S};

%%
handle_info({'$pipe', _Tx, {ioctl, b, Pid}}, #machine{bcapacity = undefined} = State) ->
   ?DEBUG("pipe ~p: bind b to ~p", [self(), Pid]),
   pipe:monitor(Pid),
   {noreply, State#machine{b = Pid}};

handle_info({'$pipe', _Tx, {ioctl, b, Pid}}, #machine{bcapacity = N} = State) ->
   ?DEBUG("pipe ~p: bind b to ~p", [self(), Pid]),
   pipe:monitor(Pid),
   pipe:ioctl_(Pid, {acredit, N}),
   {noreply, State#machine{b = Pid}};

handle_info({'$pipe', Tx, {ioctl, b}}, S) ->
   pipe:ack(Tx, {ok, S#machine.b}),
   {noreply, S};

%%
handle_info({'$pipe', _Tx, {ioctl, acredit, N}}, #machine{} = State) ->
   ?DEBUG("pipe ~p: link a credit to ~p", [self(), N]),
   {noreply, State#machine{acredit = N}};

handle_info({'$pipe', Tx, {ioctl, acredit}}, #machine{acredit = Credit} = State) ->
   pipe:ack(Tx, {ok, Credit}),
   {noreply, State};

%%
handle_info({'$pipe', _Tx, {ioctl, bcredit, N}}, #machine{} = State) ->
   ?DEBUG("pipe ~p: link b credit to ~p", [self(), N]),
   {noreply, State#machine{bcredit = N}};

handle_info({'$pipe', Tx, {ioctl, bcredit}}, #machine{bcredit = Credit} = State) ->
   pipe:ack(Tx, {ok, Credit}),
   {noreply, State};

%%
handle_info({'$pipe', Tx, {ioctl, acapacity}}, #machine{acapacity = N} = State) ->
   pipe:ack(Tx, {ok, N}),
   {noreply, State};

handle_info({'$pipe', Tx, {ioctl, bcapacity}}, #machine{bcapacity = N} = State) ->
   pipe:ack(Tx, {ok, N}),
   {noreply, State};

%%
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
   run({sidedown, a, Reason}, {pipe, B, undefined}, State);

handle_info({'DOWN', _Ref, process, B, Reason}, #machine{a = A, b = B}=State) ->
   run({sidedown, b, Reason}, {pipe, A, undefined}, State);

handle_info({'$pipe', Tx, '$free'}, State) ->
   case erlang:process_info(self(), trap_exit) of
      {trap_exit, false} ->
         pipe:ack(Tx, ok),
         {stop, normal, State};
      {trap_exit,  true} ->
         pipe:ack(Tx, ok),
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
%%
option(Key, Opts) ->
   case lists:keyfind(Key, 1, Opts) of
      false ->
         undefined;
      {_,X} ->
         X
   end.

%%
%% make pipe object for side-effect
%% Input:
%%   Tx - identity of pipe transaction
%%    A - reference of side A
%%    B - reference of side B
make_pipe(A, A, B) ->
   % Tx =:= A -> message from side A
   {pipe, A, B};
make_pipe(B, A, B) ->
   % Tx =:= B -> message from side B
   {pipe, B, A};
make_pipe(Tx, A, B)
 when Tx =:= self() ->
   % Tx =:= self() -> message is emitted by itself
   {pipe, A, B};
make_pipe(Tx, undefined, B) ->
   % process is not connected to side A
   {pipe, Tx, B};
make_pipe({A, _} = Tx, A, B) ->
   % is_sync_call(Tx) and Tx =:= A -> message from side A
   {pipe, Tx, B};
make_pipe({_, A} = Tx, A, B) ->
   % is_sync_call(Tx) and Tx =:= A -> message from side A
   {pipe, Tx, B};
make_pipe(Tx, A, _B) ->
   {pipe, Tx, A}.

%%
%% run state machine
run(Msg, Pipe, #machine{mod=Mod, sid=Sid0} = S) ->
   case Mod:Sid0(Msg, Pipe, S#machine.state) of
      {next_state, Sid, State} ->
         {noreply, credit_control(pipe:b(Pipe), S#machine{sid=Sid, state=State})};

      {next_state, Sid, State, TorH} ->
         {noreply, credit_control(pipe:b(Pipe), S#machine{sid=Sid, state=State}), TorH};

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

%%
%%
credit_control(undefined, #machine{} = State) ->
   State;

credit_control(A, #machine{a = A, acredit = undefined} = State) ->
   State;

credit_control(B, #machine{b = B, bcredit = undefined} = State) ->
   State;

credit_control(A, #machine{a = A, acredit = 0} = State) ->
   {ok, N} = pipe:ioctl(A, bcapacity),
   State#machine{acredit = N};

credit_control(A, #machine{a = A, acredit = Credit} = State) ->
   State#machine{acredit = Credit - 1};

credit_control(B, #machine{b = B, bcredit = 0} = State) ->
   {ok, N} = pipe:ioctl(B, acapacity),
   State#machine{bcredit = N};

credit_control(B, #machine{b = B, bcredit = Credit} = State) ->
   State#machine{bcredit = Credit - 1}.

