%% @doc
%% 
-module(pipe_flow_ctrl_SUITE).
-include_lib("common_test/include/ct.hrl").

%%
%% unit tests
-export([all/0]).
-export([
   capacity_allocation_dstream/1,
   capacity_allocation_ustream/1,
   credit_control_dstream/1,
   credit_control_ustream/1,
   recover_overflow_dstream/1,
   overflow_dstream/1
]).

%%% pipe behavior 
-export([init/1, free/2, pipe/3]).


all() ->
   [
      capacity_allocation_dstream,
      capacity_allocation_ustream,
      credit_control_dstream,
      credit_control_ustream,
      recover_overflow_dstream,
      overflow_dstream
   ].


capacity_allocation_dstream(_) ->
   Capacity = 3,
   {ok, A} = pipe:start(?MODULE, [a], [{acapacity, Capacity}]),
   {ok, B} = pipe:start(?MODULE, [b], [{acapacity, Capacity}]),
   {ok, C} = pipe:start(?MODULE, [c], [{acapacity, Capacity}]),
   pipe:make([A, B, C]),

   {ok, Capacity} = pipe:ioctl(A, acapacity),
   {ok, Capacity} = pipe:ioctl(B, acapacity),
   {ok, Capacity} = pipe:ioctl(C, acapacity),
   
   {ok, Capacity} = pipe:ioctl(A, bcredit),
   {ok, Capacity} = pipe:ioctl(B, bcredit),
   {ok, undefined} = pipe:ioctl(C, bcredit).


capacity_allocation_ustream(_) ->
   Capacity = 3,
   {ok, A} = pipe:start(?MODULE, [a], [{bcapacity, Capacity}]),
   {ok, B} = pipe:start(?MODULE, [b], [{bcapacity, Capacity}]),
   {ok, C} = pipe:start(?MODULE, [c], [{bcapacity, Capacity}]),
   pipe:make([A, B, C]),

   {ok, Capacity} = pipe:ioctl(A, bcapacity),
   {ok, Capacity} = pipe:ioctl(B, bcapacity),
   {ok, Capacity} = pipe:ioctl(C, bcapacity),
   
   {ok, undefined} = pipe:ioctl(A, acredit),
   {ok, Capacity} = pipe:ioctl(B, acredit),
   {ok, Capacity} = pipe:ioctl(C, acredit).


%%
credit_control_dstream(_) ->
   {ok, A} = pipe:start(?MODULE, [a], [{acapacity, 3}]),
   {ok, B} = pipe:start(?MODULE, [b], [{acapacity, 3}]),
   {ok, C} = pipe:start(?MODULE, [c], [{acapacity, 3}]),
   pipe:make([A, B, C]),

   ok = pipe:call(A, {request, 0}),
   {ok, 3} = pipe:ioctl(A, bcredit),
   {ok, 2} = pipe:ioctl(B, bcredit),
   {ok, undefined} = pipe:ioctl(C, bcredit).


%%
credit_control_ustream(_) ->
   {ok, A} = pipe:start(?MODULE, [a], [{bcapacity, 3}]),
   {ok, B} = pipe:start(?MODULE, [b], [{bcapacity, 3}]),
   {ok, C} = pipe:start(?MODULE, [c], [{bcapacity, 3}]),
   pipe:make([A, B, C]),

   ok = pipe:call(A, {request, 0}),
   timer:sleep(1500),
   {ok, undefined} = pipe:ioctl(A, acredit),
   {ok, 2} = pipe:ioctl(B, acredit),
   {ok, 3} = pipe:ioctl(C, acredit).


%%
recover_overflow_dstream(_) ->
   {ok, A} = pipe:start(?MODULE, [a], [{acapacity, 3}]),
   {ok, B} = pipe:start(?MODULE, [b], [{acapacity, 3}]),
   {ok, C} = pipe:start(?MODULE, [c], [{acapacity, 3}]),
   Head = pipe:make([A, B, C]),
   spawn(fun() ->
      lists:foreach(
         fun(Id) -> pipe:call(Head, {request, Id}) end,
         lists:seq(1, 10)
      )
   end),
   timer:sleep(1100),
   {message_queue_len, Alen} = lists:keyfind(message_queue_len, 1, erlang:process_info(A)),
   {message_queue_len, Blen} = lists:keyfind(message_queue_len, 1, erlang:process_info(B)),
   {message_queue_len, Clen} = lists:keyfind(message_queue_len, 1, erlang:process_info(C)),

   true = Alen < 2,
   true = Blen < 5,
   true = Clen < 5.


%%
overflow_dstream(_) ->
   {ok, A} = pipe:start(?MODULE, [a], []),
   {ok, B} = pipe:start(?MODULE, [b], []),
   {ok, C} = pipe:start(?MODULE, [c], []),
   Head = pipe:make([A, B, C]),
   spawn(fun() ->
      lists:foreach(
         fun(Id) -> pipe:call(Head, {request, Id}) end,
         lists:seq(1, 10)
      )
   end),
   timer:sleep(1100),
   {message_queue_len, Alen} = lists:keyfind(message_queue_len, 1, erlang:process_info(A)),
   {message_queue_len, Blen} = lists:keyfind(message_queue_len, 1, erlang:process_info(B)),
   {message_queue_len, Clen} = lists:keyfind(message_queue_len, 1, erlang:process_info(C)),

   true = Alen == 0,
   true = Blen == 0,
   true = Clen > 5.


%%%----------------------------------------------------------------------------   
%%%
%%% pipe behavior
%%%
%%%----------------------------------------------------------------------------   

init([Id]) ->
   {ok, pipe, #{id => Id}}.

free(_Reason, _State) ->
   ok.

pipe({request, Id}, Pipe, State) ->
   pipe:b(Pipe, {fast, Id}),
   pipe:a(Pipe, ok),
   {next_state, pipe, State};

pipe({fast, Id}, Pipe, State) ->
   pipe:b(Pipe, {slow, Id}),
   {next_state, pipe, State};

pipe({slow, Id}, Pipe, State) ->
   timer:sleep(500),
   pipe:a(Pipe, {ack, Id}),
   {next_state, pipe, State};

pipe({ack, Id}, Pipe, State) ->
   pipe:b(Pipe, {ack, Id}),
   {next_state, pipe, State};

pipe({sidedown, _, _}, _, State) ->
   {stop, normal, State}.


