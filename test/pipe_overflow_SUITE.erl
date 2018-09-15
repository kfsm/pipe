-module(pipe_overflow_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0]).
-export([
   no_dead_lock/1,
   congestion_side_b/1,
   congestion_side_a/1
]).

-define(FLOOD,     100).
-define(CAPACITY,  10).
-define(STRATEGY,  {one_for_all, 0, 1}).

all() ->
   [Test || {Test, NAry} <- ?MODULE:module_info(exports), 
      Test =/= module_info,
      NAry =:= 1
   ].

%%
%%
no_dead_lock(_) ->
   process_flag(trap_exit, true),

   Self = self(),
   {ok, Sup} = pipe:supervise(pipe, ?STRATEGY, [
      fun({_, _} = X) -> Self ! X; (X) -> {b, X} end,
      fun(X) -> {b, X} end,
      fun(X) -> {b, X} end,
      fun(X) -> timer:sleep(rand:uniform(4)), {b, X} end,
      fun(X) -> {a, {ok, X}} end
   ], [{capacity, ?CAPACITY}]),
   ok = flood_and_recv(Sup, ?FLOOD),
   ok = shutdown(Sup).

%%
%%
congestion_side_b(_) ->
   process_flag(trap_exit, true),
   {ok, Sup} = pipe:supervise(pipe, ?STRATEGY, [
      fun(X) -> {b, X} end,
      fun(X) -> {b, X} end,
      fun(X) -> {b, X} end,
      fun(_) -> timer:sleep(1000000) end
   ], [{capacity, ?CAPACITY}]),
   ok = flood(Sup, ?FLOOD),

   timer:sleep(1000),
   true = stage_mq(Sup, 1) > 0,
   true = stage_mq(Sup, 2) > 0,
   true = stage_mq(Sup, 3) > 0,
   true = stage_mq(Sup, 4) > ?CAPACITY,

   ok = shutdown(Sup).


congestion_side_a(_) ->
   process_flag(trap_exit, true),
   {ok, Sup} = pipe:supervise(pipe, ?STRATEGY, [
      fun(X) -> {b, X} end,
      fun({_, _}) -> timer:sleep(1000000); (X) -> {b, X} end,
      fun(X) -> {b, X} end,
      fun(X) -> {a, {ok, X}} end
   ], [{capacity, ?CAPACITY}]),
   ok = flood(Sup, ?FLOOD),

   timer:sleep(100),
   true = stage_mq(Sup, 2) > ?CAPACITY,

   ok = shutdown(Sup).


%%%------------------------------------------------------------------
%%%
%%% helper
%%%
%%%------------------------------------------------------------------   

%%
%%
flood(Sup, N) ->
   [pipe:send(pipe:head(Sup), X) || X <- lists:seq(1, N)],
   ok.

flood_and_recv(Sup, N) ->
   [pipe:send(pipe:head(Sup), X) || X <- lists:seq(1, N)],
   flood_recv(N).

flood_recv(0) ->
   ok;
flood_recv(N) ->
   receive
      {ok, N} -> 
         flood_recv(N - 1)
   after 5000  -> 
      ct:fail(timeout)
   end.

%%
%%
stage(Sup, I) ->
   erlang:element(2,
      lists:keyfind(I, 1, 
         supervisor:which_children(Sup)
      )
   ).

stage_mq(Sup, I) ->
   erlang:element(2, 
      erlang:process_info(stage(Sup, I), message_queue_len)
   ).

%%
%%
shutdown(Pid) ->
   shutdown(Pid, shutdown).

shutdown(Pid, Reason) ->
   Ref = erlang:monitor(process, Pid),
   exit(Pid, Reason),
   receive
      {'DOWN', Ref, process, Pid, noproc} ->
         dead;
      {'DOWN', Ref, process, Pid, killed} ->
         ok;
      {'DOWN', Ref, process, Pid, Reason} ->
         ok
   end.
