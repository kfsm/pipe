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
   capacity  = undefined :: integer(), %% stage capacity to handle message
   acredit   = undefined :: integer(), 
   bcredit   = undefined :: integer()
}).

%%%----------------------------------------------------------------------------   
%%%
%%% Factory
%%%
%%%----------------------------------------------------------------------------   

%%
%%
init([Mod, Args]) ->
   init(Mod:init(Args), #machine{mod = Mod}).

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

handle_info({'$pipe', _, {ioctl, capacity, Val}}, #machine{} = State) ->
   {noreply,
      State#machine{
         capacity = Val,
         acredit  = Val + rand:uniform(Val),
         bcredit  = Val + rand:uniform(Val)
      }
   };

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

handle_info({'$pipe', Tx, {ioctl, side_a_capacity}}, #machine{capacity = C}=S) ->
   pipe:ack(Tx, {side_a_credit, C}),
   {noreply, S};
handle_info({'$pipe', Tx, {ioctl, side_b_capacity}}, #machine{capacity = C}=S) ->
   pipe:ack(Tx, {side_b_credit, C}),
   {noreply, S};

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

handle_info({_, {side_a_credit, N}}, #machine{}=State) ->   
   {noreply, State#machine{acredit = N}};
handle_info({_, {side_b_credit, N}}, #machine{}=State) ->   
   {noreply, State#machine{bcredit = N}};

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
   % Tx =:= self() -> message is emited by itself
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
run(Msg, Pipe, #machine{mod=Mod, sid=Sid0}=S) ->
   case Mod:Sid0(Msg, Pipe, S#machine.state) of
      {next_state, Sid, State} ->
         {noreply, 
            consume_link_credit(pipe:b(Pipe), S#machine{sid=Sid, state=State})};

      {next_state, Sid, State, TorH} ->
         {noreply, 
            consume_link_credit(pipe:b(Pipe), S#machine{sid=Sid, state=State}), TorH};

      {reply, Reply, State} ->
         pipe:ack(Pipe, Reply),
         {noreply, 
            consume_link_credit(pipe:b(Pipe), S#machine{sid=Sid0, state=State})};

      {reply, Reply, Sid, State} ->
         pipe:ack(Pipe, Reply),
         {noreply, 
            consume_link_credit(pipe:b(Pipe), S#machine{sid=Sid, state=State})};

      {reply, Reply, Sid, State, TorH} ->
         pipe:ack(Pipe, Reply),
         {noreply, 
            consume_link_credit(pipe:b(Pipe), S#machine{sid=Sid, state=State}), TorH};

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
consume_link_credit(undefined, #machine{} = State) ->
   State;

consume_link_credit(A, #machine{a = A, acredit = undefined} = State) ->
   State;
consume_link_credit(A, #machine{a = A, acredit = 0, capacity = C} = State) ->
   {side_a_credit, N} = side_a_credit_update_protocol(A, C),
   State#machine{acredit = N};
consume_link_credit(A, #machine{a = A, acredit = Credit} = State) ->
   State#machine{acredit = Credit - 1};

consume_link_credit(B, #machine{b = B, bcredit = undefined} = State) ->
   State;
consume_link_credit(B, #machine{b = B, bcredit = 0, capacity = C} = State) ->
   {side_b_credit, N} = side_b_credit_update_protocol(B, C),
   State#machine{bcredit = N};
consume_link_credit(B, #machine{b = B, bcredit = Credit} = State) ->
   State#machine{bcredit = Credit - 1}.



side_a_credit_update_protocol(Pid, Capacity) ->
   try erlang:monitor(process, Pid) of
      Tx ->
         catch erlang:send(Pid, {'$pipe', {self(), Tx}, {ioctl, side_a_capacity}}, [noconnect]),
         receive
         {Tx, Reply} ->
            erlang:demonitor(Tx, [flush]),
            Reply;
         {'DOWN', Tx, _, _, noconnection} ->
            exit({nodedown, erlang:node(Pid)});
         {'DOWN', Tx, _, _, Reason} ->
            exit(Reason);
         {'$pipe', OtherTx, {ioctl, side_b_capacity}} ->
            pipe:ack(OtherTx, {side_b_credit, Capacity}),
            erlang:demonitor(Tx, [flush]),
            {side_a_credit, 1}
         end
   catch error:Reason ->
      exit(Reason)
   end.

side_b_credit_update_protocol(Pid, Capacity) ->
   try erlang:monitor(process, Pid) of
      Tx ->
         catch erlang:send(Pid, {'$pipe', {self(), Tx}, {ioctl, side_b_capacity}}, [noconnect]),
         receive
         {Tx, Reply} ->
            erlang:demonitor(Tx, [flush]),
            Reply;
         {'DOWN', Tx, _, _, noconnection} ->
            exit({nodedown, erlang:node(Pid)});
         {'DOWN', Tx, _, _, Reason} ->
            exit(Reason);
         {'$pipe', OtherTx, {ioctl, side_a_capacity}} ->
            pipe:ack(OtherTx, {side_a_credit, Capacity}),
            erlang:demonitor(Tx, [flush]),
            {side_b_credit, 1}
         end
   catch error:Reason ->
      exit(Reason)
   end.
