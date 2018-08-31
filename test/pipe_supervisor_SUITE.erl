-module(pipe_supervisor_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0]).
-export([
   one_for_all/1,
   rest_for_all/1,
   recovery/1,
   shutdown_with_failure/1,
   one_for_all_fault_tolerance/1,
   rest_for_all_fault_tolerance/1
]).

all() ->
   [Test || {Test, NAry} <- ?MODULE:module_info(exports), 
      Test =/= module_info,
      NAry =:= 1
   ].

%%
%%
one_for_all(_) ->
   process_flag(trap_exit, true),
   {ok, Sup} = pipe:supervise(pure, {one_for_all, 0, 1}, [
      fun(X) -> X end
   ]),
   ok = shutdown(Sup).

%%
%%
rest_for_all(_) ->
   process_flag(trap_exit, true),
   {ok, Sup} = pipe:supervise(pure, {rest_for_all, 0, 1}, [
      fun(X) -> X end
   ]),
   ok = shutdown(Sup).

%%
%%
recovery(_) ->
   process_flag(trap_exit, true),
   {ok, Sup} = pipe:supervise(pure, {one_for_all, 2, 10}, [
      fun(X) -> X end
   ]),
   failure_of_child(1, Sup),
   ok = shutdown(Sup).


%%
%%
shutdown_with_failure(_) ->
   process_flag(trap_exit, true),   
   {ok, Sup} = pipe:supervise(pure, {one_for_all, 0, 1}, [
      fun(X) -> X end
   ]),
   failure_of_child(1, Sup),
   failure(shutdown),
   dead = shutdown(Sup).

%%
%%
one_for_all_fault_tolerance(_) ->
   process_flag(trap_exit, true),
   Self = self(),   
   {ok, Sup} = pipe:supervise(pure, {one_for_all, 1000, 1000}, [
      fun(X) -> X + 1 end,
      fun(X) -> X + 1 end,
      fun(X) -> X + 1 end,
      fun(X) -> X + 1 end,
      fun(X) -> Self ! {ok, X} end
   ]),
   4 = send_to(Sup, 0),

   failure_of_child(3, Sup),
   %% Note recovery is async, wait for recovery
   timer:sleep(1000),

   4 = send_to(Sup, 0),
   ok = shutdown(Sup).

%%
%%
rest_for_all_fault_tolerance(_) ->
   process_flag(trap_exit, true),
   Self = self(),   
   {ok, Sup} = pipe:supervise(pure, {rest_for_all, 1000, 1000}, [
      fun(X) -> X + 1 end,
      fun(X) -> X + 1 end,
      fun(X) -> X + 1 end,
      fun(X) -> X + 1 end,
      fun(X) -> Self ! {ok, X} end
   ]),
   4 = send_to(Sup, 0),

   failure_of_child(3, Sup),
   %% Note recovery is async, wait for recovery
   timer:sleep(1000),

   4 = send_to(Sup, 0),
   ok = shutdown(Sup).



%%%------------------------------------------------------------------
%%%
%%% helper
%%%
%%%------------------------------------------------------------------   

%%
%%
failure_of_child(Id, Sup) ->
   {_, Pid, _, _} = lists:keyfind(Id, 1, supervisor:which_children(Sup)),
   shutdown(Pid, killed).

%%
%%
send_to(Sup, Msg) ->
   pipe:send(pipe:head(Sup), Msg),
   receive
      {ok, Result} -> Result
   after 100  -> 
      ct:fail(timeout)
   end.

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

%%
%%
failure(Reason) ->
   receive
      {'EXIT', _, Reason} ->
         ok;
      {'EXIT', _, Else} ->
         ct:fail({bad_exit_reason, Else})
   end.   
