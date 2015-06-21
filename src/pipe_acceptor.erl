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
%% @doc
%%
-module(pipe_acceptor).
-behaviour(pipe).

-export([
   start_link/3, 
   init/1, 
   free/2, 
   'LISTEN'/3
]).

%% internal state
-record(fsm, {
   sup      = undefined :: pid()
  ,acceptor = undefined :: pid()
  ,so       = undefined :: any()
}).

%%%------------------------------------------------------------------
%%%
%%% Factory
%%%
%%%------------------------------------------------------------------   

start_link(Id, Sup, Opts) ->
   pipe:start_link({local, Id}, ?MODULE, [Id, Sup, Opts], []).

init([_Id, Sup, Opts]) ->
   {ok, 'LISTEN',
      #fsm{
         sup = Sup
        ,so  = Opts  
      }
   }.

free(_Reason, _State) ->
   ok. 


%%%------------------------------------------------------------------
%%%
%%% IDLE
%%%
%%%------------------------------------------------------------------   

%%
%% @todo: monitor owner process

%%
%%
'LISTEN'(Msg, Pipe, #fsm{sup = Sup, acceptor = undefined}=State) ->
   {pipe_acceptor_sup, Pid, _, _} = lists:keyfind(pipe_acceptor_sup, 1,
      supervisor:which_children(Sup)
   ),
   'LISTEN'(Msg, Pipe, State#fsm{acceptor = Pid});

'LISTEN'({accept, Opts}, Pipe, #fsm{acceptor = Sup}=State) ->
   pipe:ack(Pipe, supervisor:start_child(Sup, Opts)),
   {next_state, 'LISTEN', State}.

% 'LISTEN'(Msg, Pipe, #fsm{acceptor = Sup}=State) ->
%    case supervisor:start_child(Sup, []) of
%       {ok, Pid} ->
%          pipe:emit(Pipe, Pid, Msg),
%          {next_state, 'LISTEN', State};
%       _         ->
%          {next_state, 'LISTEN', State}
%    end.
