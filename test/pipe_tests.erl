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
%%    unit test
-module(pipe_tests).
-include_lib("eunit/include/eunit.hrl").

%%%------------------------------------------------------------------
%%%
%%% management api
%%%
%%%------------------------------------------------------------------

pipe_test_() ->
   {
      foreach,
      fun init/0,
      fun free/1,
      [
         fun make/1,
         fun send/1,
         fun cast/1,
         fun call/1
      ]
   }.

init() ->
   [
      pipe:spawn(fun(X) -> {b, [1|X]} end),
      pipe:spawn(fun(X) -> {b, [2|X]} end),
      pipe:spawn(fun(X) -> {a, [3|X]} end)
   ].

free(Pids) ->
   pipe:free(Pids).

%%%------------------------------------------------------------------
%%%
%%% unit test
%%%
%%%------------------------------------------------------------------

make([A, Pid, B] = Pids) ->
   ?_assertMatch(
      [
         _, 
         {ioctl, b, _},
         {ok, A},
         {ok, B}
      ],
      [
         pipe:make([self() | Pids]),
         pipe:recv(),
         pipe:ioctl(Pid, a),
         pipe:ioctl(Pid, b)
      ]
   ).

send(Pids) ->
   ?_assertMatch(
      [
         _,
         {ioctl, b, _},
         [],
         [1,2,3,2,1]
      ],
      [
         pipe:make([self() | Pids]),
         pipe:recv(),
         pipe:send(hd(Pids), []),
         pipe:recv()
      ]
   ).

cast([_, _, Pid]) ->
   ?_assertMatch(
      [
         Ref,
         {Ref, [3]}
      ],
      [
         pipe:cast(Pid, []),
         receive X -> X end
      ]
   ).

call([_, _, Pid]) ->
   ?_assertMatch(
      [
         [3],
         [3]
      ],
      [
         pipe:call(Pid, []),
         gen_server:call(Pid, [])
      ]
   ).


