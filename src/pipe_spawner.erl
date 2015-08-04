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
%%   pipeline factory 
-module(pipe_spawner).
-behaviour(pipe).

-export([
   start_link/2, 
   start_link/3, 
   init/1, 
   free/2, 
   ondemand/3,
   pool/3
]).

%% internal state
-record(fsm, {
   mod      = undefined :: atom()
  ,opts     = undefined :: list()
  ,n        = undefined :: integer()
  ,pool     = []        :: list()
}).

%%%------------------------------------------------------------------
%%%
%%% Factory
%%%
%%%------------------------------------------------------------------   

start_link(Mod, Opts) ->
   pipe:start_link(?MODULE, [Mod, Opts], []).

start_link(Name, Mod, Opts) ->
   pipe:start_link({local, Name}, ?MODULE, [Mod, Opts], []).


init([Mod, Opts]) ->
   hook_owner(Opts),
   {State, N} = check_mode(Opts),
   {ok, State,
      #fsm{
         mod  = Mod
        ,opts = Opts
        ,n    = N
      }
   }.

free(_Reason, _State) ->
   ok. 


%%%------------------------------------------------------------------
%%%
%%% handle
%%%
%%%------------------------------------------------------------------   

%%
%%
ondemand({spawn, Opts1, Flags}, Pipe, #fsm{mod = Mod, opts = Opts0} = State) ->
   Pids = make(Mod, Opts0 ++ Opts1),
   pipe:a(Pipe, {ok, bind(Pipe, Pids, Flags)}),
   {next_state, ondemand, State};

ondemand({'DOWN', _Ref, _Type, _Pid, _Reason}, _, State) ->
   {stop, normal, State}.

%%
%%
pool({spawn, Opts1, Flags}, Pipe, #fsm{pool = [Head|Tail]} = State) ->
   Bind = bind(Pipe, Head, Flags),
   pipe:send(Bind, {spawn, Opts1}),
   pipe:a(Pipe, {ok, Bind}),
   {next_state, handle, State#fsm{pool = Tail}};

pool({spawn, Opts1, Flags}, Pipe, #fsm{mod = Mod, opts = Opts0, pool = []} = State) ->
   Pids = make(Mod, Opts0),
   Bind = bind(Pipe, Pids, Flags),
   pipe:send(Bind, {spawn, Opts1}),
   pipe:a(Pipe, {ok, Bind}),
   {next_state, handle, State#fsm{pool = pool(State)}};

pool({'DOWN', _Ref, _Type, _Pid, _Reason}, _, #fsm{pool = Pool} = State) ->
   lists:foreach(fun pipe:free/1, Pool),
   {stop, normal, State}.


%%%------------------------------------------------------------------
%%%
%%% private
%%%
%%%------------------------------------------------------------------   

%%
%% monitor owner process
hook_owner(Opts) ->
   {owner, Pid} = lists:keyfind(owner, 1, Opts),
   erlang:monitor(process, Pid).

%%
%% check spawner execution mode
check_mode(Opts) ->
   case lists:keyfind(pool, 1, Opts) of
      false     -> 
         {ondemand, 0};
      {pool, N} ->
         {pool, N}
   end.

%%
%% check spawn flags
is(Key, Flags) ->
   lists:member(Key, Flags).

%%
%% init pool
pool(#fsm{mod = Mod, opts = Opts0, n = N}) ->
   lists:map(
      fun(_) -> 
         make(Mod, Opts0) 
      end,
      lists:seq(1, N)
   ).

%%
%% bind pipeline with owner process
bind(Pipe, Pids, Flags) ->
   From = pipe:a(Pipe),
   case {is(iob2b, Flags), is(nopipe, Flags)} of
      {true, _} ->
         X = pipe:make(Pids),
         _ = pipe:bind(b, lists:last(Pids), From),
         _ = pipe:bind(b, From, lists:last(Pids)),
         X;

      {_, true} ->
         pipe:make(Pids);

      {_,   _} ->
         pipe:make(Pids ++ [From])
   end.

%%
%%
make(default, Opts) ->
   [pipe:spawn(X) || X <- Opts, erlang:is_function(X)];
make({Mod, Fun}, Opts) ->
   Mod:Fun(Opts);
make(Mod, Opts)
 when is_atom(Mod) ->
   Mod:spawn(Opts).

