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
%%
-define(is_pid(X),  is_pid(X) orelse is_tuple(X) orelse is_atom(X)).


