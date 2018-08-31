%% @doc
%%   Example process to feature supervisor behavior
-module(process).
-behaviour(pipe).

-export([
   start_link/0,
   init/1,
   ioctl/2,
   free/2,
   handle/3
]).

start_link() -> 
   pipe:start_link(?MODULE, [], []).

init(_) ->
   {ok, handle, undefined}.

free(_, _) ->
   ok.

ioctl({_, Val}, _) ->
   Val;
ioctl(_, Val) ->
   Val.

handle(do_next_state, Pipe, State) ->
   pipe:ack(Pipe, ok),
   {next_state, handle, State};

handle(do_reply, _, State) ->
   {reply, ok, handle, State};

handle(do_next_state_hibernate, Pipe, State) ->
   pipe:ack(Pipe, ok),
   {next_state, handle, State, hibernate};

handle(do_reply_hibernate, _, State) ->
   {reply, ok, handle, State, hibernate};

handle(do_stop, Pipe, State) ->
   pipe:ack(Pipe, ok),
   {stop, normal, State};

handle(do_upgrade, Pipe, State) ->
   pipe:ack(Pipe, ok),
   {upgrade, ?MODULE, []};

handle(Msg, Pipe, State) ->
   {next_state, handle, State}.
