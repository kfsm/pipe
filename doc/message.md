# Message Passing Interface

The library implements an alternative inter process communication protocol. The major objective is to eliminate difference between synchronous, asynchronous and out-of-bound messages processing. The protocol support process chaining and allow clients to choose synchronous/asynchronous communication patterns while preserve uniform implementation. The library keeps interface semantic compatible to gen_server.

## Communication primitives


### synchronous

The execution of message originator is blocked until recipient outputs successful or unsuccessful result message. The originator process waits for response or it is terminated by timeout. The synchronous is a typical scenario for client - server interactions. The state transition function has to acknowledge the message to return the result to client.

```erlang
-spec call(pid(), _) -> _.
-spec call(pid(), _, timeout()) -> _.
```


### asynchronous 

The execution of message originator is not blocked. However, it implies that originator process waits for successful or unsuccessful response. The output of recipient is delivered to mailbox of originator process. Each asynchronous request is tagged by unique reference thus client can monitor the server response. The asynchronous communication allows to execute multiple parallel service calls towards multiple recipients. For example, asynchronous long-lasting I/O to external systems.

```erlang
-spec cast(pid(), _) -> reference().
-spec cast(pid(), _, [atom()]) -> reference().
```

### out-of-bound

The execution of message originator is not blocked. The originator processes do not have intent to to track results of service execution (fire-and-forget mode), unlike an asynchronous messages. 

```erlang
-spec send(pid(), _) -> _.
-spec send(pid(), _, [atom()]) -> _.
```

### acknowledgment

The acknowledgment is a signal passed between communicating processes that confirms acceptance of  ingress messages. The pipe protocol uses piggy-back acknowledgment to deliver response to message originator process. This function adapts automatically to communication patterns chosen by client.


```erlang
-spec ack(pipe() | tx(), any()) -> any().
```

## Running example

You can find example implementation of message passing in [examples/pingpong](../examples/pingpong).

Let's compile example
```
cd ./examples/pingpong/ ; ../../rebar3 compile ; cd -
make run
```

Let's run the example at development console

```erlang
%%
%% spawn ping-pong server (state machine)
pingpong:start_link().

%%
%% use synchronous call, method blocks the console until 'pong' message is received
pipe:call(pingpong, ping).


%%
%% use asynchronous communication, method return reference immediately 
%% (e.g. #Ref<0.0.1.30>)
pipe:cast(pingpong, ping).

%%
%% the response is delivered to mailbox of the console.
%% it is tagged with same reference as cast reposted
%%  (e.g. {#Ref<0.0.1.30>,pong})
flush().

%%
%% use fire-and-forget, not reply is delivered to the console.
pipe:send(pingpong, ping).


%%
%% the protocol is compatible with gen_server and Erlang message-passing primitives
gen_server:call(pingpong, ping).
gen_server:cast(pingpong, ping).
pingpong ! ping.
```
