# pipe behavior

The library provides `pipe` behavior for state machine implementation. The standard set of predefined callback functions are used to enhance generic state machine behavior (similar to other gen_xxx modules).

## interface

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

```erlang
-spec init(list()) -> {ok, atom(), state()} | {error, any()}.
```

The function is called whenever the state machine process is started using either start_link or start function. It build internal state data structure, defines initial state transition, etc. The function should return either `{ok, Sid, State}` or `{error, Reason}`. 


### free/2 

```erlang
-spec free(any(), state()) -> ok.
```

The function is called to release resource owned by state machine, it is called when the process is about to terminate.


### ioctl/2

```erlang
-spec ioctl(atom() | {atom(), any()}, state()) -> any() | state().
```

The function is optional, generic I/O control interface to read/write state machine attributes. 


### StateName/3 

```erlang
-spec StateName(any(), pipe(), state()) -> {next_state, sid(), state()} 
                                           |  {stop, any(), state()} 
                                           |  {upgrade, atom(), [any()]}.
```
 
The state transition function receive any message, which is sent using pipe interface or any other Erlang message passing operation. The function executes the state transition, generates output or terminate execution. 


## Running example

You can find example implementation of pipe behavior in [examples/pincode](../examples/pincode).

Let's compile example
```
cd ./examples/pincode/ ; ../../rebar3 compile ; cd -
make run
```

Let's run the example at development console

```erlang
%%
%% spawn state machine with pin-code
pincode:start_link([1,2,3,4]).

%%
%% check status of state machine, it should be locked
pincode:check().

%%
%%
enter pin-code
lists:foreach(fun pincode:digit/1, [1,2,3,4]).

%%
%% check status of state machine, it should be unlocked
pincode:check().

%%
%% wait about 10 - 15 seconds and check status again, it should be locked
pincode:check().

```
