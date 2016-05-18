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
%%   pipe stream is a computation using notation of streams
%%   see https://github.com/fogfish/datum for details
-module(pipe_stream).

-export([
   start_link/1,
   init/2
]).


start_link(Stream) ->
   proc_lib:start_link(?MODULE, init, [self(), Stream]).

init(Parent, Stream) ->
   proc_lib:init_ack(Parent, {ok, self()}),
   setup(Stream, undefined, undefined).
   
%%
%% setup phase, stream stage is bound to side (a) and side (b)
setup(Stream, A, B) ->
   receive
      %% bind side a
      {'$pipe', _, {ioctl, a, Pid}} when B =:= undefined ->
         setup(Stream, Pid, B);

      {'$pipe', _, {ioctl, a, Pid}} ->
         stream(Stream, Pid, B);

      %% bind side b
      {'$pipe', _, {ioctl, b, Pid}} when A =:= undefined ->
         setup(Stream, A,  Pid);

      {'$pipe', _, {ioctl, b, Pid}} ->
         stream(Stream, A, Pid)
   end.

%%
%% execution phase, stream stage is bound
stream(Stream, A, B) ->
   stream:foreach(
      fun(X) -> pipe:send(B, X) end,
      Stream(message(A))
   ).

%%
%% message stream
message(A) ->
   receive
      {'$pipe', _, {ioctl, _, _}} ->
         message(A);

      {'$pipe', _, {ioctl, _}} ->
         message(A);

      {'$pipe', Tx, Msg} ->
         pipe:ack(Tx, ok),
         stream:new(Msg, fun() -> message(A) end)
   end.
