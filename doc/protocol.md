# pipe internal protocol


life-cycle
```erlang
{'$pipe', pid(), '$free'}
```

ioctl
```erlang
{'$pipe', tx(), {ioctl, atom()}}
{'$pipe', tx(), {ioctl, atom(), any()}}
```

ioctl - bind
```erlang
{'$pipe', tx(), {ioctl, a, pid()}}
{'$pipe', tx(), {ioctl, a}}
```

```erlang
recv(Timeout, Opts) ->
   receive
   {'$pipe', _Pid, Msg} ->
      Msg
   after Timeout ->
      recv_error(Opts, timeout)
   end.

recv(Pid, Timeout, Opts) ->
   Ref  = {_, Tx, _} = pipe:monitor(process, Pid),
   receive
   {'$pipe', Pid, Msg} ->
      pipe:demonitor(Ref),
      Msg;
   {'$pipe',   _, {ioctl, _, Pid} = Msg} ->
      pipe:demonitor(Ref),
      Msg;      
   {'DOWN', Tx, _, _, noconnection} ->
      pipe:demonitor(Ref),
      recv_error(Opts, {nodedown, erlang:node(Pid)});
   {'DOWN', Tx, _, _, Reason} ->
      pipe:demonitor(Ref),
      recv_error(Opts, Reason);
   {nodedown, Node} ->
      pipe:demonitor(Ref),
      recv_error(Opts, {nodedown, Node})
   after Timeout ->
      recv_error(Opts, timeout)
   end.
```
