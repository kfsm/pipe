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
-include_lib("common_test/include/ct.hrl").

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
   stream(Stream, Send, undefined, undefined).
   
%%
%% execution phase, stream stage is bound
stream(Stream, Send, A, B) ->
   case
      catch stream:foreach(
         fun(X) -> pipe:Send(B, X) end,
         stream:filter(
            fun(X) -> X /= undefined end,
            Stream(message(A))
         )
      )
   of
      {ioctl, a, Pid} ->
         stream(Stream, Send, Pid, B);
      {ioctl, b, Pid} ->
         stream(Stream, Send, A, Pid);
      Reason ->
         exit(Reason)
   end.


%%
%% message stream
message(A) ->
   receive
      {'$pipe', _, {ioctl, _, _} = Setup} ->
         throw(Setup);

      {'$pipe', _, {ioctl, _}} ->
         message(A);

      {'$pipe', Tx, Msg} ->
         stream:new(Msg, 
            fun() ->
               %% Note: this code acknowledges received message once it is consumed by stream handler  
               pipe:ack(Tx, ok),
               message(A) 
            end
         )
   end.
