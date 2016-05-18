# Pipeline 

A pipeline organizes complex processing tasks through several simple Erlang processes, which are called _stages_. Each stage receives message from other pipeline stages, processes them in some way, and sends transformed message back to the pipeline. The stage has predecessor / source (a) and successor / sink (b). The message always flows from (a) to (b).

## Pipeline primitives


### bind/3

```erlang
-spec bind(a | b, pid()) -> {ok, pid()}.
-spec bind(a | b, pid(), pid()) -> {ok, pid()}.
```

The operation binds stages together defining processing pipeline. The function takes side identity either atom `a` or `b` as first argument, stage identity owning a side as second and destination process identity as third one (it uses `self()` if third argument is not defined). The example below illustrates binding procedure. Internally binding is implemented using `ioctl` protocol for properties `a` or `b`.

```erlang
%%
%% self() --(a)--[ Pid ]--(b)-- ...
bind(a, Pid, self()).

%%
%%    ... --(a)--[ Pid ]--(b)-- self()
bind(b, Pid, self()).
```

### make/1

```erlang
-spec make([pid()]) -> pid().
```

It is a helper function to make a pipeline from multiple stage. It return `pid()` of pipeline head.


### a/2, b/2

```erlang
-spec a(pipe(), _) -> ok.
-spec b(pipe(), _) -> ok.
```

Send message through pipe either to side (a) or (b). The function is used inside pipe behavior. From behavior perspective side (a) always points to message sender, side (b) - to next stage in pipeline.


## Running example

You can find example implementation of pipeline in [examples/flow](../examples/flow).

Let's compile example
```
cd ./examples/flow/ ; ../../rebar3 compile ; cd -
make run
```

Let's run the example at development console
```erlang
%%
%% Let's create two stages that increment input message by one
{ok, A} = flow:start_link().
{ok, B} = flow:start_link().

%% and third stage that print result to console only if its value great then N
{ok, C} = flow:start_link(3).

%%
%% Let's bind these stages to computation pipeline
P = pipe:make([A, B, C]).

%%
%% Evaluate pipeline, it outputs "==> 3" to console  
pipe:send(P, 1).

%%
%% Evaluate pipeline, it outputs "==> 7" to console  
pipe:send(P, 5).

%%
%% Evaluate pipeline, it outputs nothing to console
pipe:send(P, 0).
```

Let's run pipeline example using lambda functions at development console
```erlang
%% There is a function
%%    y = 2 * x + 5

%%
%% Let's build stages, computation elements
A = pipe:fspawn(fun(X) -> 2 * X end).
B = pipe:fspawn(fun(X) -> X + 5 end).

%%
%% bind stages together, making a computation
F = pipe:make([A, B]).

%%
%% bind output of last computation element to console process, so that it receives result
pipe:bind(b, B).

%%
%% evaluate computation and receive result
pipe:send(F, 10).
pipe:recv().

```

