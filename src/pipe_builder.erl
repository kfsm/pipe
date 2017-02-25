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
-module(pipe_builder).
-behaviour(pipe).

-export([
   start_link/1,
   init/1,
   free/2,
   handle/3
]). 

start_link(Sup) ->
   pipe:start_link(?MODULE, [Sup], []).

init([Sup]) ->
   erlang:send(self(), rebuild),
   {ok, handle, Sup}.

free(_Reason, _Sup) ->
   ok.

handle(rebuild, _, Sup) ->
   pipe:make([Pid || {_, Pid, _, _} <- supervisor:which_children(Sup), Pid /= self()]),
   {next_state, handle, Sup};

handle(_, _, Sup) ->
   {next_state, handle, Sup}.

