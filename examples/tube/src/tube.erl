%%
%%   Copyright (c) 2012 - 2013, Dmitry Kolesnikov
%%   Copyright (c) 2012 - 2013, Mario Cardona
%%   All Rights Reserved.
%%
%%   Licensed under the Apache License, Version 2.0 (the "License");
%%   you may not use this file except in compliance with the License.
%%   You may obtain a copy of the License at
%%
%%       http://www.apache.org/licenses/LICENSE-2.0
%%
%%   Unless required by applicable law or agreed to in writing, software
%%   distributed under the License is distributed on an "AS IS" BASIS,
%%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%   See the License for the specific language governing permissions and
%%   limitations under the License.
%%
%% @description
%%   pipe library example
-module(tube).

-export([make/1]).

%%
%%
make(Pipe) ->
	%% spawn pipeline elements
	L = [pipe:spawn(create(F)) || F <- Pipe],
	%% bind pipeline elements
	_ = pipe:make(L),
	%% bind pipeline to current process
	_ = pipe:bind(a, hd(L)),
	_ = pipe:bind(b, lists:last(L)),
	%% return closure
	fun(X) ->
		_ = pipe:send(hd(L), X),
		pipe:recv(infinity)
	end.

%%
%%
create({'+', Y}) -> 
	add(Y);
create({'-', Y}) ->
	sub(Y).

%%
%%
add(Y) ->
	fun(X) -> X + Y end.	

%%
%%
sub(Y) ->
	fun(X) -> X - Y end.

	

