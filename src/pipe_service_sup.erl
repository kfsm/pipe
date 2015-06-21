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
%%   service supervisor
-module(pipe_service_sup).
-behaviour(supervisor).

-export([
   start_link/2, 
   init/1
   % %% api
   % init_socket/4,
   % init_acceptor/2,

   % leader/1,
   % acceptor/1
]).

%%
%%
-define(CHILD(Type, I),            {I,  {I, start_link,   []}, permanent, 5000, Type, dynamic}).
-define(CHILD(Type, I, Args),      {I,  {I, start_link, Args}, permanent, 5000, Type, dynamic}).
-define(CHILD(Type, ID, I, Args),  {ID, {I, start_link, Args}, permanent, 5000, Type, dynamic}).

%%
%%
start_link(Id, Opts) ->
   supervisor:start_link(?MODULE, [Id, Opts]).

init([Id, Opts]) -> 
   {ok,
      {
         {one_for_all, 0, 1},
         [
            ?CHILD(supervisor, pipe_acceptor_sup, [opts(acceptor, Opts)])
           ,?CHILD(worker,     pipe_acceptor,     [Id, self(), Opts])
         ]
         % lists:flatten([
         %    %% accept socket factory
         %    accept_socket_factory(Uri)
         %    %% acceptor factory
         %   ,?CHILD(supervisor, knet_acceptor_sup, [Uri, opts:val(acceptor, Opts)])
         %    %% listener socket (automatically listen incoming connection)
         %   ,?CHILD(worker,     knet_daemon, [self(), Uri, Opts])
         % ])
      }
   }.

opts(Key, Opts) ->
   erlang:element(2,
      lists:keyfind(Key, 1, Opts)
   ).

% accept_socket_factory(Uri) ->
%    case knet_protocol:is_accept_socket(uri:schema(Uri)) of
%       false -> 
%          [];
%       true  -> 
%          ?CHILD(supervisor, knet_sock_sup, [Uri])
%    end.



% %%
% %% create new socket using socket factory 
% init_socket(Sup, Uri, Owner, Opts) ->
%    {knet_sock_sup, Factory, _Type, _Mods} = lists:keyfind(knet_sock_sup, 1, supervisor:which_children(Sup)),
%    case supervisor:start_child(Factory, [Uri, Owner, Opts]) of
%       {ok, Pid} -> 
%          knet_sock:socket(Pid);
%       Error     -> 
%          Error
%    end.

% %%
% %% create new acceptor using acceptor factory
% init_acceptor(Sup, Uri) ->
%    {knet_acceptor_sup, Factory, _Type, _Mods} = lists:keyfind(knet_acceptor_sup, 1, supervisor:which_children(Sup)),
%    supervisor:start_child(Factory, [Uri]).


% %%
% %%
% leader(Sup)
%  when is_pid(Sup) ->
%    {knet_sock, Pid, _Type, _Mods} = lists:keyfind(knet_sock, 1, supervisor:which_children(Sup)),
%    Pid.

% %%
% %%
% acceptor(Sup)
%  when is_pid(Sup) ->
%    {knet_acceptor_sup, Pid, _Type, _Mods} = lists:keyfind(knet_acceptor_sup, 1, supervisor:which_children(Sup)),
%    Pid.
