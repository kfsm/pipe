%% @description
%%    example pass pipe
-module(pipe_pass).
% -include("kfsm.hrl").

% -export([
%    start_link/0, init/1, free/2, pass/3
% ]).

% start_link() ->
%    pipe_process:start_link(?MODULE, []).

% init(_) ->
%    random:seed(erlang:now()),
%    {ok, pass, undefined}.

% free(_, _) ->
%    ok.

% pass(Msg, Pipe, S) ->
%    io:format("pass ~p: ~p~n", [self(), Msg]),
%    case random:uniform(5) of
%       1 ->

%    _ = pipe:b(Pipe, Msg),
%    {next_state, pass, S}.