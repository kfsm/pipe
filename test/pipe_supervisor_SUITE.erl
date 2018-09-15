-module(pipe_supervisor_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0]).
-export([
   one_for_all/1
,  rest_for_all/1
,  recovery_permanent/1
,  recovery_transient/1

,  shutdown_normal_temporary/1
,  shutdown_normal_transient/1
,  shutdown_normal_permanent/1

,  shutdown_faults_temporary/1
,  shutdown_faults_transient/1
,  shutdown_faults_permanent/1

,  fault_tolerance_transient/1
,  fault_tolerance_permanent/1
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
      fun(X) -> X end,
      fun(X) -> X end
   ]),
   ok = shutdown(Sup).

%%
%%
rest_for_all(_) ->
   process_flag(trap_exit, true),
   {ok, Sup} = pipe:supervise(pure, {rest_for_all, 0, 1}, [
      fun(X) -> X end,
      fun(X) -> X end
   ]),
   ok = shutdown(Sup).

%%
%%
recovery_permanent(_) ->
   process_flag(trap_exit, true),
   {ok, Sup} = pipe:supervise(pure, {permanent, one_for_all, 2, 10}, [
      fun(X) -> X end,
      fun(X) -> X end
   ]),
   failure_of_child(1, Sup),
   child_exists(1, Sup),
   ok = shutdown(Sup).

%%
%%
recovery_transient(_) ->
   process_flag(trap_exit, true),
   {ok, Sup} = pipe:supervise(pure, {transient, one_for_all, 2, 10}, [
      fun(X) -> X end,
      fun(X) -> X end
   ]),
   failure_of_child(1, Sup),
   child_exists(1, Sup),
   ok = shutdown(Sup).

%%
%%
shutdown_normal_temporary(_) ->
   process_flag(trap_exit, true),
   {ok, Sup} = pipe:supervise(pure, {temporary, one_for_all, 2, 10}, [
      fun(X) -> X end,
      fun(X) -> X end
   ]),
   shutdown_of_child(1, Sup),
   failure(normal),
   dead = shutdown(Sup).

shutdown_normal_transient(_) ->
   process_flag(trap_exit, true),
   {ok, Sup} = pipe:supervise(pure, {transient, one_for_all, 2, 10}, [
      fun(X) -> X end,
      fun(X) -> X end
   ]),
   shutdown_of_child(1, Sup),
   failure(normal),
   dead = shutdown(Sup).

shutdown_normal_permanent(_) ->
   process_flag(trap_exit, true),
   {ok, Sup} = pipe:supervise(pure, {permanent, one_for_all, 2, 10}, [
      fun(X) -> X end,
      fun(X) -> X end
   ]),
   shutdown_of_child(1, Sup),
   child_exists(1, Sup),
   ok = shutdown(Sup).


%%
%%
shutdown_faults_temporary(_) ->
   process_flag(trap_exit, true),   
   {ok, Sup} = pipe:supervise(pure, {temporary, one_for_all, 2, 10}, [
      fun(X) -> X end,
      fun(X) -> X end
   ]),
   failure_of_child(1, Sup),
   failure(shutdown),
   dead = shutdown(Sup).


%%
%%
shutdown_faults_transient(_) ->
   process_flag(trap_exit, true),   
   {ok, Sup} = pipe:supervise(pure, {transient, one_for_all, 2, 10}, [
      fun(X) -> X end,
      fun(X) -> X end
   ]),
   failure_of_child(1, Sup),
   child_exists(1, Sup),
   ok = shutdown(Sup).

%%
%%
shutdown_faults_permanent(_) ->
   process_flag(trap_exit, true),   
   {ok, Sup} = pipe:supervise(pure, {permanent, one_for_all, 2, 10}, [
      fun(X) -> X end,
      fun(X) -> X end
   ]),
   failure_of_child(1, Sup),
   child_exists(1, Sup),
   ok = shutdown(Sup).

%%
%%
fault_tolerance_transient(_) ->
   process_flag(trap_exit, true),   
   {ok, Sup} = pipe:supervise(pure, {transient, one_for_all, 2, 10}, [
      fun(X) -> X end,
      fun(X) -> X end
   ]),
   failure_of_child(1, Sup),
   child_exists(1, Sup),

   failure_of_child(2, Sup),
   child_exists(2, Sup),

   failure_of_child(1, Sup),
   failure(shutdown),
   dead = shutdown(Sup).

%%
%%
fault_tolerance_permanent(_) ->
   process_flag(trap_exit, true),   
   {ok, Sup} = pipe:supervise(pure, {permanent, one_for_all, 2, 10}, [
      fun(X) -> X end,
      fun(X) -> X end
   ]),
   failure_of_child(1, Sup),
   child_exists(1, Sup),

   failure_of_child(2, Sup),
   child_exists(2, Sup),

   failure_of_child(1, Sup),
   failure(shutdown),
   dead = shutdown(Sup).

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

shutdown_of_child(Id, Sup) ->
   {_, Pid, _, _} = lists:keyfind(Id, 1, supervisor:which_children(Sup)),
   shutdown(Pid, normal, fun(_) -> pipe:free(Pid) end).

%%
%%
child_exists(Id, Sup) ->
   {_, _, _, _} = lists:keyfind(Id, 1, supervisor:which_children(Sup)).


%%
%%
shutdown(Pid) ->
   shutdown(Pid, shutdown).

shutdown(Pid, Reason) ->
   shutdown(Pid, Reason, fun(X) -> exit(Pid, X) end).

%%
%%
shutdown(Pid, Reason, Fun) ->
   Ref = erlang:monitor(process, Pid),
   Fun(Reason),
   receive
      {'DOWN', Ref, process, Pid, noproc} ->
         dead;
      {'DOWN', Ref, process, Pid, killed} ->
         ok;
      {'DOWN', Ref, process, Pid, Reason} ->
         ok
   after 1000 ->
      ct:fail({fail_to_shutdown, Pid, Reason})
   end.

%%
%%
failure(Reason) ->
   receive
      {'EXIT', _, Reason} ->
         ok;
      {'EXIT', _, Else} ->
         ct:fail({bad_exit_reason, Else})
   after 1000 ->
      ct:fail({fail_to_exit, Reason})
   end.   
