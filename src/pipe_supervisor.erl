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
%% @doc
%%   reusable pipeline supervisor
-module(pipe_supervisor).
-behaviour(gen_server).

-export([
   start_link/3
,  init/1
,  terminate/2
,  handle_call/3
,  handle_cast/2
,  handle_info/2
,  code_change/3
]).

-record(state, {
   lifecycle = undefined :: transient | temporary | permanent 
,  strategy  = undefined :: one_for_all
,  intensity = undefined :: non_neg_integer()
,  interval  = undefined :: non_neg_integer()
,  spec      = undefined :: [_]
,  opts      = undefined :: [_]
,  stages    = undefined :: [_]
,  failure   = []  
}).

%%%----------------------------------------------------------------------------   
%%%
%%% Factory
%%%
%%%----------------------------------------------------------------------------   

start_link(Mod, Args, Opts) ->
   gen_server:start_link(?MODULE, [Mod, Args, Opts], []).

%% 
%%
init([Mod, Args, Opts]) ->
   process_flag(trap_exit, true),
   {ok, {Supervisor, Spec}} = Mod:init(Args),
   {ok,
      init_pipe(#state{
         lifecycle = lifecycle(spec(Supervisor)),
         strategy  = strategy(spec(Supervisor)),
         intensity = intensity(spec(Supervisor)),
         interval  = interval(spec(Supervisor)),
         spec      = Spec,
         opts      = Opts
      })
   }.

spec({_, _, _, _} = Spec) -> 
   Spec;
spec({Strategy, Intensity, Interval}) -> 
   {permanent, Strategy, Intensity, Interval}.


lifecycle({permanent, _, _, _}) ->
   permanent;
lifecycle({transient, _, _, _}) ->
   transient;
lifecycle({temporary, _, _, _}) ->
   temporary.

strategy({_, one_for_one, _, _}) ->
   one_for_all;
strategy({_, one_for_all, _, _}) ->
   one_for_all;
strategy({_, rest_for_all, _, _}) ->
   one_for_all.

intensity({_, _, Intensity, _})
 when Intensity >= 0 ->
   Intensity.

interval({_, _, _, Interval})
 when Interval >= 0 ->
   Interval.

%%
%%
terminate(_, #state{} = State) ->
   free_pipe(State),
   ok.

%%
%%
handle_info({'EXIT', Pid, normal}, #state{lifecycle = temporary} = State) ->
   heir(normal, Pid, State),
   {stop, normal, State};

handle_info({'EXIT', Pid, Reason}, #state{lifecycle = temporary} = State) ->
   heir(Reason, Pid, State),
   {stop, shutdown, State};

handle_info({'EXIT', Pid, normal}, #state{lifecycle = transient} = State) ->
   heir(normal, Pid, State),
   {stop, normal, State};

handle_info({'EXIT', Pid, Reason}, #state{lifecycle = transient} = State) ->
   recover_pipe(Reason, Pid, State);

handle_info({'EXIT', Pid, Reason}, #state{lifecycle = permanent} = State) ->
   recover_pipe(Reason, Pid, State);

handle_info(_, State) ->
   {noreply, State}.

%%
%%
handle_cast(_, State) ->
   {noreply, State}.

%%
%%
handle_call(which_children, _, #state{stages = Stages} = State) ->
   {reply,
      [{Id, Pid, worker,dynamic} || {Id, Pid} <- Stages],
      State
   }.

%%
%%
code_change(_Vsn, State, _) ->
   {ok, State}.

%%
%%
heir(Reason, Pid, #state{opts = Opts}) ->
   case proplists:get_value(heir, Opts) of
      undefined ->
         ok;
      Heir ->
         Heir ! {'DOWN', self(), pipe, Pid, Reason}
   end.

%%
%%
recover_pipe(Reason, Pid, #state{} = State0) ->
   case is_permanent_failure(State0) of
      {false, State1} ->
         {noreply, respawn(State1)};
      {true,  State1} ->
         heir(Reason, Pid, State1),
         {stop, shutdown, State1}
   end.

is_permanent_failure(#state{failure = Failure0, interval = Interval, intensity = Intensity} = State) ->
   T0 = erlang:monotonic_time(seconds),
   T1 = T0 - Interval,
   Failure1 = lists:filter(fun(X) -> X >= T1 end, [T0 | Failure0]),
   {length(Failure1) > Intensity, State#state{failure = Failure1}}.

%%
%%
init_pipe(#state{spec = Spec, opts = Opts} = State) ->
   Pids = pipe:make([init_pipe_stage(MFA) || MFA <- Spec], Opts),
   State#state{
      stages = lists:zip(lists:seq(1, length(Pids)), Pids)
   }.

init_pipe_stage({M, F, A}) ->
   {ok, Pid} = (catch erlang:apply(M, F, A)),
   Pid.


%%
%%
free_pipe(#state{stages = Stages} = State) ->
   lists:foreach(fun free_pipe_stage/1, Stages),
   State#state{ 
      stages = undefined
   }.

free_pipe_stage({_, Pid}) ->
   %% See Erlang/OTP supervisor for details
   erlang:monitor(process, Pid),
   erlang:unlink(Pid),
   receive
      {'EXIT', Pid, Reason} -> 
         receive 
            {'DOWN', _, process, Pid, _} ->
               {error, Reason}
         end
   after 0 -> 
      exit(Pid, shutdown),
      receive 
         {'DOWN', _MRef, process, Pid, shutdown} ->
            ok;
         {'DOWN', _MRef, process, Pid, Reason} ->
            {error, Reason}
         % @todo: shutdown timeout
         % after Time ->
         %    exit(Pid, kill),
         %    receive
         %    {'DOWN', _MRef, process, Pid, Reason} ->
         %       {error, Reason}
         %    end
      end
   end.

%%
%%
respawn(State) ->
   init_pipe(free_pipe(State)).



