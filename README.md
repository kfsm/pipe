# pipe - process i/o protocol.

The library implements alternative inter process communication protocol including flow control support. The major objective is eliminate difference between synchronous, asynchronous and out-of-bound messages handling.

## Background

Erlang processes interact each other by sending _synchronous_, _asynchronous_ 
_out-of-bound_ and _pipeline_ messages.

### synchronous

the execution of message originator is blocked until recipient outputs 
successful or unsuccessful result message. The originator process waits for 
response or timeouts. The synchronous is a typical scenario for client - server 
interactions.

```
pipe:call(...)  <----->  pipe:ack(...) 
```

### asynchronous 

the execution of message originator is not blocked, the recipient outputs
message is delivered to mailbox of originator process. The asynchronous message
request implies that originator process waits for successful or unsuccessful 
responses. The scenario allows to execute multiple parallel service calls 
towards multiple recipients  (e.g. asynchronous external I/O, _long-lasting_ 
requests).

```
pipe:cast(...) <-----> pipe:ack(...)
```

### out-of-bound

the execution of message originator is not blocked, unlike an asynchronous
message, the originator processes do not have intent to to track results of
service execution (fire-and-forget mode).

```
pipe:send(...) ------> [pipe:ack(...)] %% only if flow control is needed
```

### pipeline

A pipeline organizes complex processing tasks through several simple Erlang 
processes, which are called _stages_. Each stage receives message from other 
pipeline stages, processes them in some way, and sends transformed message back 
to the pipeline. The stage has predecessor / source (a) and successor / sink (b).
The message always flows from (a) to (b).

```
pipe:send(...)
pipe:a(...)
pipe:b(...)
```

## Processes


## Message passing protocol

The message is Erlang tuple ```{'$pipe', tx(), any()}```.

### synchronous

```tx() :: {pid(), reference()}```
   
```tx()``` term is compatible with ```gen_server:reply(...)``` protocol.

### asynchronous

```tx() :: {reference(), pid()}```

### out-of-bound

```tx() :: pid()```

### pipeline

```tx() :: pid()```


Options:
 - _yield_ yield current process
 - _noconnect_ do not connect to remote node
 - _flow_ use credit base flow control


### Flow control
   
Consume credit:
   - cast
   - send

Gain credit:
   a    -
   ack  - 


## Pipeline
