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
%%   parallel call 
-module(pipe_call_fsm).
-behaviour(pipe).

-export([
   start_link/0 
  ,init/1 
  ,free/2
  ,ioctl/2
  ,idle/3 
  ,active/3
]).

%% internal state
-record(fsm, {
   tx      = undefined :: any()                  %% client transaction
  ,pid     = undefined :: [{pid(), reference()}] %% list of process(es) / monitor(s)
  ,timer   = undefined :: reference()            %% transaction timer
  ,success = undefined :: [{pid(), any()}]       %% list of succeeds requests
  ,failure = undefined :: [pid()]                %% list of failed processes
}).

%%%----------------------------------------------------------------------------   
%%%
%%% Factory
%%%
%%%----------------------------------------------------------------------------   

start_link() ->
   pipe:start_link(?MODULE, [], []).

init([]) ->
   {ok, idle, #fsm{}}.

free(_, _) ->
   ok.

ioctl(_, _) ->
   throw(not_supported).

%%%----------------------------------------------------------------------------   
%%%
%%% FSM
%%%
%%%----------------------------------------------------------------------------   

%%
%%
idle({pcall, Pids, Req, Timeout}, Tx, #fsm{}=State) ->
   {next_state, active, 
      State#fsm{
         tx      = Tx
        ,pid     = [request(Pid, Req) || Pid <- Pids]
        ,timer   = timer_init(Timeout)
        ,success = []
        ,failure = []
      }
   }.

%%
%%
active({'DOWN',  _Ref, _, Pid, _Reason}, _, #fsm{}=State) ->
   case lists:keydelete(Pid, 1, State#fsm.pid) of
      [] ->
         reply(State#fsm{failure=[Pid | State#fsm.failure]}),
         {next_state, idle, #fsm{}};
      X  ->
         {next_state, active, 
            State#fsm{
               failure = [Pid | State#fsm.failure]
              ,pid     = X
            }
         }
   end;

active({timeout, _Ref, undefined}, _, #fsm{}=State) ->
   reply(lists:foldl(fun response/2, State, State#fsm.pid)),
   {stop, normal, #fsm{}};

active({Tx, Reply}, _, #fsm{}=State) ->
   case lists:keytake(Tx, 2, State#fsm.pid) of
      {value, {Pid, Tx, Ref}, []} ->
         pipe:demonitor(Ref),
         reply(State#fsm{success=[{Pid, Reply} | State#fsm.success]}),
         {next_state, idle, #fsm{}};
      {value, {Pid, Tx, Ref}, X} ->
         pipe:demonitor(Ref),
         {next_state, active, 
            State#fsm{
               success = [{Pid, Reply} | State#fsm.success]
              ,pid     = X
            }
         }
   end.

%%%----------------------------------------------------------------------------   
%%%
%%% private
%%%
%%%----------------------------------------------------------------------------   

%%
%%
timer_init(infinity) -> undefined;
timer_init(Timeout)  -> erlang:start_timer(Timeout, self(), undefined).

%%
%%
timer_free(Timer) ->
   case catch erlang:cancel_timer(Timer) of
      % timer is already expired, consume it's message
      false ->
         receive
            {timeout, Timer, _} -> ok
         after 0 ->
            ok
         end;
      % timer is canceled 
      _ -> 
         ok
   end.


%%
%% request process
request(Pid, Msg) ->
   Ref = {_, Tx, _} = pipe:monitor(process, Pid),
   catch erlang:send(Pid, {'$pipe', {self(), Tx}, Msg}, [noconnect]),
   {Pid, Tx, Ref}.

%%
%% read process response from mailbox
response({Pid, Tx, _}, #fsm{}=State) ->
   receive
   {'DOWN', Tx, _, Pid, _Reason} ->
      State#fsm{failure=[Pid | State#fsm.failure]};
   {Tx, Reply} ->
      State#fsm{success=[{Pid, Reply} | State#fsm.success]}
   after 0 ->
      State#fsm{failure=[Pid | State#fsm.failure]}
   end.

%%
%% reply transaction to client
reply(#fsm{}=State) ->
   timer_free(State#fsm.timer),
   pipe:ack(State#fsm.tx, {lists:reverse(State#fsm.success), lists:reverse(State#fsm.failure)}).
