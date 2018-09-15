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
%%   lambda expression inside pipe
-module(pipe_lambda).
-behaviour(pipe).

-export([
   init/1,
   free/2,
   handle/3
]).

init([Fun]) ->
   {ok, handle, Fun}.

free(_, _Fun) ->
   ok.

handle({sidedown, _, _}, _, Fun) ->
   {next_state, handle, Fun};

handle(In, Pipe, Fun) ->
   case Fun(In) of
      stop ->
         {stop, normal, Fun};

      {a, Eg} when Eg /= undefined ->
         pipe:a(Pipe, Eg),
         {next_state, handle, Fun};

      {b, Eg} when Eg /= undefined ->
         pipe:b(Pipe, Eg),
         {next_state, handle, Fun};

      Lambda when is_function(Lambda) ->
         {next_state, handle, Lambda};

      _       ->
         {next_state, handle, Fun}
   end.
