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
-behaviour(supervisor).

-export([
   start_link/2, 
   init/1,
   head/1
]).

%%
-define(CHILD(I),            {I,  {I, start_link,   []}, transient, infinity, worker, dynamic}).
-define(CHILD(I, Args),      {I,  {I, start_link, Args}, transient, infinity, worker, dynamic}).
-define(CHILD(ID, I, Args),  {ID, {I, start_link, Args}, transient, infinity, worker, dynamic}).


%%
start_link(Mod, Args) ->
   {ok, Sup} = supervisor:start_link(?MODULE, [Mod, Args]),
   %% Note: supervisor shall grantee determinism, boot-up is blocked until pipeline is linked
   {_, Linker, _, _} = lists:keyfind(pipe_supervisor_linker, 1, supervisor:which_children(Sup)),
   ok = pipe:call(Linker, is_linked, infinity),
   {ok, Sup}.
   
init([Mod, Args]) ->
   {ok, {Strategy, Spec}} = Mod:init(Args),
   {ok,
      {
         strategy(Strategy),
         child_spec(Spec) ++ [?CHILD(pipe_supervisor_linker, [self()])]
      }
   }. 

%%
strategy({one_for_all, _, _} = Strategy) ->
   Strategy;
strategy({_, Rate, Time}) ->
   {rest_for_one, Rate, Time}.

%%
child_spec(Spec) ->
   child_spec(1, Spec).
child_spec(Id, [{_, _, _} = Head | Tail]) ->
   [{Id, Head, transient, infinity, worker, dynamic} | child_spec(Id + 1, Tail)];
child_spec(_, []) ->
   [].

%%
head(Sup) ->
   erlang:element(2,
      lists:keyfind(1, 1, 
         supervisor:which_children(Sup)
      )
   ).
