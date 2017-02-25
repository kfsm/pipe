-module(pipe_a).

-export([start_link/0, init/1, free/2, ioctl/2, handle/3]).

start_link() ->
   pipe:start_link(?MODULE, [], []).

init(_) ->
   {ok, handle, #{x => 0}}.

free(_, _) ->
   ok.

ioctl({Key, Val}, State) ->
   maps:put(Key, Val, State);

ioctl(Key, State) ->
   maps:get(Key, State).

handle(X, Pipe, State) ->
   pipe:b(Pipe, X + 1),
   {next_state, handle, State#{x => X}}.
