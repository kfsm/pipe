%% @description
%%    unit test
-module(pipe_tests).
-include_lib("eunit/include/eunit.hrl").

%%%------------------------------------------------------------------
%%%
%%% test pipe stage
%%%
%%%------------------------------------------------------------------

-export([
   init/1
  ,free/2
  ,ioctl/2
  ,handle/3
]).

init(_) ->
   {ok, handle, {}}.

free(_, _) ->
   ok.

ioctl(_, _) ->
   throw(not_supported).

handle(_X, _Tx, S) ->
   {next_state, handle, S}.


%%%------------------------------------------------------------------
%%%
%%% management api
%%%
%%%------------------------------------------------------------------

pipe_test_() ->
   {
      setup,
      fun pipe_init/0,
      fun pipe_free/1,
      [
         {"pipe spawn/free", fun pipe_spawn_free/0}
        ,{"pipe bind",  fun pipe_bind/0}
        ,{"pipe make pipeline", fun pipe_make_pipeline/0}
      ]
   }.

pipe_init() ->
   ok.

pipe_free(_) ->
   ok.

%%
%% pipe stage life cycle test(s)
pipe_spawn_free() ->
   pipe_spawn_free(spawn, fun(X) -> X end),
   pipe_spawn_free(spawn_link, fun(X) -> X end),
   pipe_spawn_free(spawn_monitor, fun(X) -> X end),

   pipe_spawn_free(start, ?MODULE),
   pipe_spawn_free(start_link, ?MODULE).

pipe_spawn_free(Id, Fun)
 when is_function(Fun) ->
   Pid = case pipe:Id(Fun) of
      {X, _} -> X;
      X      -> X
   end,
   ok    = pipe:free(Pid),
   timer:sleep(10),
   false = erlang:is_process_alive(Pid);

pipe_spawn_free(Id, Mod)
 when is_atom(Mod) ->
   {ok, Pid} = pipe:Id(?MODULE, [], []),
   ok        = pipe:free(Pid),
   timer:sleep(10),
   false = erlang:is_process_alive(Pid),

   {ok, P1d} = pipe:Id({local, ?MODULE}, ?MODULE, [], []),
   ok        = pipe:free(P1d),
   timer:sleep(10),
   false = erlang:is_process_alive(P1d).

%%
%% pipe stage(s) bind
pipe_bind() ->
   A = pipe:spawn(fun(X) -> X end),
   B = pipe:spawn(fun(X) -> X end),
   pipe_bind(A, B),
   _ = pipe:free(A),
   _ = pipe:free(B),

   {ok, C} = pipe:start(?MODULE, [], []),
   {ok, D} = pipe:start(?MODULE, [], []),
   pipe_bind(C, D),
   _ = pipe:free(C),
   _ = pipe:free(D).


pipe_bind(A, B) ->
   P = self(),
   {ok, _} = pipe:bind(a, A),
   {ok, _} = pipe:bind(b, A, B),
   {ok, _} = pipe:bind(a, B, A),
   {ok, _} = pipe:bind(b, B),

   {ok, P} = pipe:ioctl(A, a),
   {ok, B} = pipe:ioctl(A, b),
   {ok, A} = pipe:ioctl(B, a),
   {ok, P} = pipe:ioctl(B, b).

%%
%%  
pipe_make_pipeline() ->
   Pids = [pipe:spawn(fun(X) -> X end) || _ <- lists:seq(1, 10)],
   _    = pipe:make(Pids),
   _    = pipe:free(Pids).



%%%------------------------------------------------------------------
%%%
%%% asynchronous
%%%
%%%------------------------------------------------------------------

async_io_test_() ->
   {
      setup,
      fun async_io_init/0,
      fun async_io_free/1,
      [
          {"async send to raw", fun async_send_raw/0}
         ,{"async send to fsm", fun async_send_fsm/0}
      ]
   }.

async_io_init() ->
   Fun  = fun(X) -> timer:sleep(X), X + 1 end,
   Pids = [pipe:spawn(Fun) || _ <- lists:seq(1, 10)],
   _    = pipe:make(Pids),
   erlang:register(pipe_raw_head, hd(Pids)),
   erlang:register(pipe_raw_tail, lists:last(Pids)),
   Pids.

async_io_free(Pids) ->
   erlang:unregister(pipe_raw_head),
   erlang:unregister(pipe_raw_tail),
   pipe:free(Pids).

async_send_raw() ->
   {ok, _} = pipe:bind(a, erlang:whereis(pipe_raw_head)),
   {ok, _} = pipe:bind(b, erlang:whereis(pipe_raw_tail)),

   pipe:send(pipe_raw_head, 0),
   10 = pipe:recv(),

   pipe:send(pipe_raw_tail, 0),
   10 = pipe:recv().

async_send_fsm() ->
   ok.


%%%------------------------------------------------------------------
%%%
%%% synchronous
%%%
%%%------------------------------------------------------------------

sync_io_test_() ->
   {
      setup,
      fun sync_io_init/0,
      fun sync_io_free/1,
      [
        % {"create", fun create/0}
        %,{"lookup", fun lookup/0}
      ]
   }.

sync_io_init() ->
   ok.

sync_io_free(_Pids) ->
   ok.




%%%------------------------------------------------------------------
%%%
%%% private
%%%
%%%------------------------------------------------------------------

%%
%%
accumulator() ->
   ok.

