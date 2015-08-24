# pipe - a generic, lightweight finite state machine implementation in Erlang

The library provides simple behavior for finite state machine (FSM) implementation. This behavior is proposed as an alternative to built gen_fsm and gen_servers. The major objective is to eliminate difference between synchronous, asynchronous and out-of-bound messages processing. The library also implements primitives to chain these state machines for complex data processing pipelines.

## State machine

The library implements ```pipe``` behavior for implementing state machines. The standard set of pre-defined callback function is used to enhance generic state machine behavior (similar to other gen_xxx modules).

```
pipe module               callback module
-----------               ---------------
pipe:start
pipe:start_link --------> Module:init/1

pipe:free       --------> Module:free/2

pipe:ioctl      --------> Module:ioctl/2

pipe:call
pipe:cast
pipe:send       --------> Module:StateName/3
```

### init/1 

```
init/1 :: (list()) -> {ok, atom(), state()} | {error, any()}
```

The function is called whenever the state machine process is started using either start_link or start function. It build internal state data structure, defines initial state transition, etc. The function should return either `{ok, Sid, State}` or `{error, Reason}`. 


### free/2 

```
free/2 :: (any(), state()) -> ok
```

The function is called to release resource owned by state machine, it is called when the process is about to terminate.

### ioctl/2

```
ioctl/2 :: (atom() | {atom(), any()}, state()) -> any() | state()
```

The function is optional, generic I/O control interface to read/write state machine attributes. 

### StateName/3 

```
StateName/3 :: (any(), pipe(), state()) -> {next_state, sid(), state()} 
                                        |  {stop, any(), state()} 
                                        |  {upgrade, atom(), [any()]}
```
 
The state transition function receive any message, which is sent using pipe interface or any other Erlang message passing operation. The function executes the state transition, generates output or terminate execution. 


## Message passing

The library implements alternative inter process communication protocol. The major objective is to eliminate difference between synchronous, asynchronous and out-of-bound messages handling. It makes an assumption that Erlang processes interact each other by sending _synchronous_, _asynchronous_ 
_out-of-bound_ messages or they are organized to _pipelines_.

### synchronous

The execution of message originator is blocked until recipient outputs 
successful or unsuccessful result message. The originator process waits for 
response or it is terminated by timeout. The synchronous is a typical scenario 
for client - server interactions. The state transition function has to acknowledge
the message to return the result to client.

```
pipe:call(...)  <----->  pipe:ack(...) 
```

### asynchronous 

The execution of message originator is not blocked. However, it implies that 
originator process waits for successful or unsuccessful response. The output of 
recipient is delivered to mailbox of originator process. Each asynchronous request
is tagged by unique reference thus client can monitor the server response. The 
asynchronous communication allows to execute multiple parallel service calls 
towards multiple recipients  (e.g. asynchronous external I/O, _long-lasting_ 
requests).

```
pipe:cast(...) <-----> pipe:ack(...)
```

### out-of-bound

the execution of message originator is not blocked, unlike an asynchronous
message, the originator processes do not have intent to to track results of
service execution (fire-and-forget mode). The message acknowledgment is optional
but it is recommended. The library automatically send response to originator process
if it is required by protocol. 

```
pipe:send(...) ------> [pipe:ack(...)]
```

### example

```
-module(server).
-behaviour(pipe).

-export([
   start_link/0,
   init/1,
   free/2,
   handle/3]
).
-export([
   ping/1
]).

start_link() ->
   pipe:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
   {ok, handle, #{}}.

free(_Reason, _State) -> 
   ok.

ping(Pid) -> 
   pipe:call(Pid, ping).

ping_(Pid) ->
   pipe:cast(Pid, ping).

handle(ping, Pipe, State) ->
   pipe:ack(Pipe, pong),
   {next_state, handle, State}.
```

## Pipeline

A pipeline organizes complex processing tasks through several simple Erlang 
processes, which are called _stages_. Each stage receives message from other 
pipeline stages, processes them in some way, and sends transformed message back 
to the pipeline. The stage has predecessor / source (a) and successor / sink (b).
The message always flows from (a) to (b).

