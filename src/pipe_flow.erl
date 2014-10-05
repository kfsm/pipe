%% @description
%%   credit based flow control
-module(pipe_flow).
-include("pipe.hrl").

-export([
   credit/1
  ,credit/2
  ,consume/1   
  ,consume/2   
  ,produce/1
  ,recv/2
  ,send/1
]).

%%
%% consume credit and suspends execution if process runs out of credits
-spec(consume/1 :: (pid()) -> integer()).
-spec(consume/2 :: (pid(), timeout()) -> integer()).

consume(Pid) ->
   case get({credit, default}) of
      undefined    -> consume(Pid, 1000);
      {_, Timeout} -> consume(Pid, Timeout)
   end.

consume(Pid, Timeout) ->
   case credit(Pid) of
      1 -> 
         case recv(Pid, Timeout) of
            undefined -> erase({credit, Pid});
            X         -> put({credit, Pid}, X)
         end;
      X -> 
         put({credit, Pid}, X - 1)
   end.

%%
%% produce credit to process
-spec(produce/1 :: (pid()) -> ok). 

produce(Pid) ->
   case credit(Pid) of
      1 -> 
         put({credit, Pid}, send(Pid));
      X -> 
         put({credit, Pid}, X - 1)
   end.


%%
%% return credit value associated with process
-spec(credit/1 :: (pid()) -> integer()).

credit(Pid) ->
   case get({credit, Pid}) of
      undefined ->
         case get({credit, default}) of
            undefined     -> ?DEFAULT_CREDIT_A;
            {X, _Timeout} -> X
         end;
      X ->
         X
   end.

%%
%% gain credit
-spec(credit/2 :: (pid(), integer()) -> ok).

credit(Pid, Value) ->
   Default = case get({credit, default}) of
      undefined     -> ?DEFAULT_CREDIT_A;
      {X, _Timeout} -> X
   end,
   put({credit, Pid}, erlang:min(credit(Pid) + Value, Default)),
   ok.

%%
%% receive credit from processes
-spec(recv/2 :: (pid(), timeout()) -> integer() | undefined). 

recv(Pid, Timeout) ->
   Ref = {_, Tx, _} = pipe:monitor(Pid),
   receive
      {'$flow', Pid, Credit} ->
         pipe:demonitor(Ref),
         Credit;
      {'DOWN', Tx, _, _, noconnection} ->
         pipe:demonitor(Ref),
         undefined;
      {'DOWN', Tx, _, _, _Reason} ->
         pipe:demonitor(Ref),
         undefined;
      {nodedown, _Node} ->
         pipe:demonitor(Ref),
         undefined
   after Timeout ->
      1
   end.   

%%
%% send credit to process
-spec(send/1 :: (pid()) -> ok).

send(Pid) ->
   Credit = case get({credit, default}) of
      undefined -> ?DEFAULT_CREDIT_B;
      {X,    _} -> X
   end,
   erlang:send(Pid, {'$flow', self(), Credit}),
   Credit.
