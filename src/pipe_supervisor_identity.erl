-module(pipe_supervisor_identity).

-export([init/1]).

init([Strategy, Spec]) ->
  {ok, {Strategy, Spec}}.