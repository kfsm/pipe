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
%%   The process stays at supervisor tree, it re-build the pipeline after each restart
-module(pipe_supervisor_linker).
-behaviour(pipe).

-export([
   start_link/2,
   init/1,
   free/2,
   handle/3
]). 

-record(state, {
   join_side_a = undefined :: undefined | pid(),
   join_side_b = undefined :: undefined | pid(),
   heir_side_a = undefined :: undefined | pid(),
   heir_side_b = undefined :: undefined | pid(),
   capacity    = undefined :: undefined | pid(),
   supervisor  = undefined :: undefined | pid() 
}).

start_link(Sup, Opts) ->
   pipe:start_link(?MODULE, [Sup, Opts], []).

init([Sup, Opts]) ->
   self() ! link,
   {ok, handle, 
      #state{
         join_side_a = proplists:get_value(join_side_a, Opts),
         join_side_b = proplists:get_value(join_side_b, Opts),
         heir_side_a = proplists:get_value(heir_side_a, Opts),
         heir_side_b = proplists:get_value(heir_side_b, Opts),
         capacity    = proplists:get_value(capacity, Opts),
         supervisor  = Sup
      }
   }.

free(_Reason, _State) ->
   ok.

handle(link, _, State) ->
   heir_side(State,
      build(
         join_side(State,
            capacity(State, 
               stages(State)
            )
         )
      )
   ),
   {next_state, handle, State};

handle(is_linked, _, State) ->
   {reply, ok, State}.

%%
stages(#state{supervisor = Sup}) ->
   lists:map(
      fun({_, Pid, _, _}) -> Pid end,
      lists:keysort(1,
         lists:filter(
            fun({_, Pid, _, _}) -> Pid /= self() end,
            supervisor:which_children(Sup)
         )
      )
   ).

%%
capacity(#state{capacity = undefined}, Stages) ->
   Stages;
capacity(#state{capacity = Capacity}, Stages) ->
   [stage_capacity(Capacity, Pid) || Pid <- Stages].

stage_capacity(Capacity, Pid) ->
   pipe:ioctl_(Pid, {capacity, Capacity}),
   Pid.

%%
join_side(#state{join_side_a = undefined, join_side_b = undefined}, Stages) ->
   Stages;
join_side(#state{join_side_a = SideA, join_side_b = undefined}, Stages) ->
   [SideA | Stages];
join_side(#state{join_side_a = undefied, join_side_b = SideB}, Stages) ->
   Stages ++ [SideB];
join_side(#state{join_side_a = SideA, join_side_b = SideB}, Stages) ->
   [SideA | Stages] ++ [SideB].

%%
build(Stages) ->
   pipe:make(Stages),
   Stages.

%%
heir_side(#state{heir_side_a = undefined, heir_side_b = undefined}, Stages) ->
   Stages;
heir_side(#state{heir_side_a = SideA, heir_side_b = undefined}, Stages) ->
   pipe:bind(a, hd(Stages), SideA),
   Stages;
heir_side(#state{heir_side_a = undefined, heir_side_b = SideB}, Stages) ->
   pipe:bind(b, lists:last(Stages), SideB),
   Stages;
heir_side(#state{heir_side_a = SideA, heir_side_b = SideB}, Stages) ->
   pipe:bind(a, hd(Stages), SideA),
   pipe:bind(b, lists:last(Stages), SideB),
   Stages.
