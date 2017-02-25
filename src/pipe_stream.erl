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
   start_link/2,
   init/3
]).


start_link(Stream, Opts) ->
   proc_lib:start_link(?MODULE, init, [self(), Stream, Opts]).

init(Parent, Stream, Opts) ->
   proc_lib:init_ack(Parent, {ok, self()}),
   Send = case lists:member(sync, Opts) of
      true  -> call;
      false -> send
   end,
   setup(Stream, Send, undefined, undefined).
   
%%
%% setup phase, stream stage is bound to side (a) and side (b)
setup(Stream, Send, A, B) ->
   receive
      %% bind side a
      {'$pipe', _, {ioctl, a, Pid}} when B =:= undefined ->
         setup(Stream, Send, Pid, B);

      {'$pipe', _, {ioctl, a, Pid}} ->
         stream(Stream, Send, Pid, B);

      %% bind side b
      {'$pipe', _, {ioctl, b, Pid}} when A =:= undefined ->
         setup(Stream, Send, A,  Pid);

      {'$pipe', _, {ioctl, b, Pid}} ->
         stream(Stream, Send, A, Pid)
   end.

%%
%% execution phase, stream stage is bound
stream(Stream, Send, A, B) ->
   stream:foreach(
      fun(X) -> pipe:Send(B, X) end,
      stream:filter(
         fun(X) -> X /= undefined end,
         Stream(message(A))
      )
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
         stream:new(Msg, 
            fun() ->
               %% acknowledge message one it is consumed  
               pipe:ack(Tx, ok),
               message(A) 
            end
         )
   end.
