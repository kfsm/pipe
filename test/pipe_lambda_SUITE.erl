-module(pipe_lambda_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0]).
-export([
   puref/1,
   pipef/1
]).

all() ->
   [Test || {Test, NAry} <- ?MODULE:module_info(exports), 
      Test =/= module_info,
      NAry =:= 1
   ].

%%
%%
puref(_) ->
   process_flag(trap_exit, true),
   Self = self(),
   {ok, Sup} = pipe:supervise(pure, {one_for_all, 0, 1}, [
      fun(X) -> X end,
      fun(X) -> X end,
      fun(X) -> X end,
      fun(X) -> Self ! {ok, X} end
   ]),
   1 = send_to(Sup, 1),
   ok = shutdown(Sup).

%%
%%
pipef(_) ->
   process_flag(trap_exit, true),
   Self = self(),
   {ok, Sup} = pipe:supervise(pipe, {one_for_all, 0, 1}, [
      fun(X) -> {b, X} end,
      fun(X) -> {b, X} end,
      fun(X) -> {b, X} end,
      fun(X) -> Self ! {ok, X} end
   ]),
   1 = send_to(Sup, 1),
   ok = shutdown(Sup).

%%%------------------------------------------------------------------
%%%
%%% helper
%%%
%%%------------------------------------------------------------------   

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
