# Pipe Supervisor

> a process that supervises other processes called child processes.

Pipe supervisor is a process that ensures consistency of defined pipeline. It is responsible either recover or terminate entire pipeline if case of stage failure (similarly to [OTP supervisor](http://erlang.org/doc/design_principles/sup_princ.html)).  

The pipe supervisor implements one of the following restart strategies:

* `one_for_all` - entire pipeline is restarted
* `rest_for_one` - pipeline is partially restarted depends, starting from failed stage.  


The usage of pipe supervisor does not differs from traditional one. You defines restart strategy and list of children with spawn, see [full example](examples/supervisor/src/one_for_all_sup.erl). A child spec is only exception, pipeline always consists of transient worker processes. Therefore, you only need to specify a module, function and arguments for each stage processes.


```erlang
start_link() ->
   pipe:supervisor(?MODULE, []).

init([]) ->
   {ok,
      {
         {one_for_one, 1, 3600},
         [
            {process, start_link, []},
            ...
         ]
      }
   }.
```

The library also supports shortcuts for pipeline composition build either from pipe or pure functions. See [full example](examples/supervisor/src/composition_sup.erl)

```
pipe:supervisor(pipe | pure | stream, {one_for_one, 1, 3600}, [
   fun a/1,
   fun b/1,
   ...
]).
```
