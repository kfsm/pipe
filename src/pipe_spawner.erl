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
   handle/3
]).

%% internal state
-record(fsm, {
   mod      = undefined :: atom()
  ,opts     = undefined :: list()
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
   {ok, handle,
      #fsm{
         mod  = Mod
        ,opts = Opts  
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
handle({spawn, Opts1, Flags}, Pipe, #fsm{mod = Mod, opts = Opts0} = State) ->
   From = pipe:a(Pipe),
   Pids = Mod:spawn(Opts0 ++ Opts1),

   %% bind socket pipeline with owner process
   case {flag(iob2b, Flags), flag(nopipe, Flags)} of
      {true, _} ->
         X = pipe:make(Pids),
         _ = pipe:bind(b, Pids, From),
         _ = pipe:bind(b, From, lists:last(Pids)),
         pipe:a(Pipe, {ok, X});

      {_, true} ->
         pipe:a(Pipe,
            {ok, pipe:make(Pids ++ [From])}
         );

      {_,    _} ->
         pipe:a(Pipe,
            {ok, pipe:make(Pids)}
         )
   end,
   {next_state, handle, State}.   

%%%------------------------------------------------------------------
%%%
%%% private
%%%
%%%------------------------------------------------------------------   

flag(Key, Flags) ->
   lists:member(Key, Flags).


