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
%%   service root supervisor
-module(pipe_service_root_sup).
-behaviour(supervisor).

-export([
   start_link/0, 
   init/1,
   %% api
   init_service/2,
   free_service/1
]).

%%
-define(CHILD(Type, I),            {I,  {I, start_link,   []}, temporary, 5000, Type, dynamic}).
-define(CHILD(Type, I, Args),      {I,  {I, start_link, Args}, temporary, 5000, Type, dynamic}).
-define(CHILD(Type, ID, I, Args),  {ID, {I, start_link, Args}, temporary, 5000, Type, dynamic}).

%%
start_link() ->
   supervisor:start_link({local, ?MODULE}, ?MODULE, []).
   
init([]) -> 
   {ok,
      {
         {one_for_one, 4, 1800},
         []
      }
   }.

%%
%% initialize net service
init_service(Id, Opts) ->
   supervisor:start_child(?MODULE, 
      ?CHILD(supervisor, Id, pipe_service_sup, [Id, Opts])
   ).

%%
%% terminate net service
free_service(Id) ->
   case supervisor:terminate_child(?MODULE, Id) of
      ok    ->
         supervisor:delete_child(?MODULE, Id);
      Error ->
         Error
   end.


