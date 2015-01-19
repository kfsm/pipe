%% @description
%%   process multiplex example
%%
%%   ( a ) -*--1- ( mux ) -1--*- ( b )
%%
%%   stage ( a ) is a client process consuming service from ( b ) stage,
%%   stage ( mux ) is global process, used by ( a ) to discover one of available ( b ) stage 
-module(mux).

-export([
   start_link/0,
   spawn_link/0
]).

%%
%% start multiplex and worker ( b ) pipe's
start_link() ->
   Pool = [mux_b:start_link(Id) || Id <- lists:seq(0, 10)],
   mux_m:start_link([Pid || {ok, Pid} <- Pool]).

%%
%% spawn client ( a ) pipe's
spawn_link() ->
   mux_a:start_link(). 