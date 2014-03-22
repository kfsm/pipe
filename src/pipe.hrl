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
%-define(CONFIG_DEBUG, true).

-ifdef(CONFIG_DEBUG).
   -define(DEBUG(Str, Args), error_logger:info_msg(Str, Args)).
-else.
   -define(DEBUG(Str, Args), ok).
-endif.

%% default pipe container
-define(CONFIG_PIPE,     pipe_process).

%% default pipe timeout
-define(CONFIG_TIMEOUT,  5000).


%%
%% I/O flags 
-define(IO_YIELD,     1).
-define(IO_NOCONNECT, 2).
-define(IO_FLOW,      4).


%%
%% derived from RabbitMQ server credit_flow.erl
-define(FLOW_CTL(Pid, Default, Var, Expr),
   begin
     case get({credit, Pid}) of
         undefined -> Var = Default;
         Var       -> ok
     end,
     put({credit, Pid}, Expr)
   end
).

%%
%%
-define(DEFAULT_CREDIT_A,   200).
-define(DEFAULT_CREDIT_B,   200).

