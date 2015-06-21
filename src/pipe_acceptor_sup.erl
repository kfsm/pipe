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
%%   acceptor factory - creates "application" protocol stack   
-module(pipe_acceptor_sup).
-behaviour(supervisor).

-export([
   start_link/1, 
   init/1
]).

%%
-define(CHILD(Type, I),            {I,  {I, start_link,   []}, temporary, 5000, Type, dynamic}).
-define(CHILD(Type, I, Args),      {I,  {I, start_link, Args}, temporary, 5000, Type, dynamic}).
-define(CHILD(Type, ID, I, Args),  {ID, {I, start_link, Args}, temporary, 5000, Type, dynamic}).

%%
%%
start_link(Acceptor) ->
   supervisor:start_link(?MODULE, [Acceptor]).


init([{Acceptor, Method, Args}]) ->
   {ok,
      {
         {simple_one_for_one, 1000000, 1},
         [
            {Acceptor, {Acceptor, Method, Args}, temporary, 5000, worker, dynamic}
         ]
      }
   };
init([{Acceptor, Args}]) -> 
   {ok,
      {
         {simple_one_for_one, 1000000, 1}, 
         [
            ?CHILD(worker, Acceptor, Args)
         ]
      }
   }; 
init([Acceptor]) -> 
   {ok,
      {
         {simple_one_for_one, 1000000, 1},
         [
            ?CHILD(worker, Acceptor)
         ]
      }
   }.


