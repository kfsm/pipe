# pipe 

A generic, lightweight finite state machine implementation in Erlang

[![Build Status](https://secure.travis-ci.org/kfsm/pipe.svg?branch=master)](http://travis-ci.org/kfsm/pipe)

## Inspiration

The actor model is often criticized by amount of boilerplate code to define actor; by absence of actor's composition formalism. Despite the fact that Erlang's Actor model outperforms a similar concepts and implementation from multiple dimensions, developers experience similar issue. This library provides an alternative to `gen_fsm` and `gen_server` behaviors. It defines a simplified interface for finite state machine (FSM) implementation. Additionally, it simplifies a semantic of synchronous, asynchronous and out-of-bound messages processing. The library also implements primitives to chain these state machines for complex data processing pipelines.


## Getting started

The latest version of the library is available at its master branch. All development, including new features and bug fixes, take place on the master branch using forking and pull requests as described in contribution guidelines.

### Installation

If you use `rebar` you can include `pipe` library in your project with
```
{pipe, ".*",
   {git, "https://github.com/kfsm/pipe", {branch, master}}
}
```

### Usage

The library exposes _public_ interface through exports of [pipe.erl](src/pipe.erl) module. Just call required function with required arguments, check out _More Information_ chapter for details. 

Build library and run the development console
```
make
make run
```


## Supported features

### pipe behavior

The library provides [pipe behavior](doc/behavior.md) for state machine implementation. The standard set of predefined callback functions are used to enhance generic state machine behavior (similar to other gen_xxx modules).


### message passing interface

The library implements alternative [inter process communication protocol](doc/message.md). The major objective is to eliminate difference between synchronous, asynchronous and out-of-bound messages processing. It is expected that usage pattern and protocol defines necessary acknowledgment patterns but the implementation is uniform.


### pipeline

A pipeline organizes complex processing tasks through several simple Erlang processes, which are called _stages_. Each stage receives message from other pipeline stages, processes them in some way, and sends transformed message back to the pipeline. The stage has predecessor / source (a) and successor / sink (b). The message always flows from (a) to (b).




### More Information

* study [pipe behavior interface](doc/behavior.md) and [example](examples/pincode) of state machine implementation. 
* understand [message passing interface](doc/message.md) and ping-pong server [example](examples/pingpong)



## How to Contribute

`pipe` is Apache 2.0 licensed and accepts contributions via GitHub pull requests.

### getting started

* Fork the repository on GitHub
* Read the README.md for build instructions
* Make pull request

### commit message

The commit message helps us to write a good release note, speed-up review process. The message should address two question what changed and why. The project follows the template defined by chapter [Contributing to a Project](http://git-scm.com/book/ch5-2.html) of Git book.

>
> Short (50 chars or less) summary of changes
>
> More detailed explanatory text, if necessary. Wrap it to about 72 characters or so. In some contexts, the first line is treated as the subject of an email and the rest of the text as the body. The blank line separating the summary from the body is critical (unless you omit the body entirely); tools like rebase can get confused if you run the two together.
> 
> Further paragraphs come after blank lines.
> 
> Bullet points are okay, too
> 
> Typically a hyphen or asterisk is used for the bullet, preceded by a single space, with blank lines in between, but conventions vary here
>

## Bugs

If you detect a bug, please bring it to our attention via GitHub issues. Please make your report detailed and accurate so that we can identify and replicate the issues you experience:
- specify the configuration of your environment, including which operating system you're using and the versions of your runtime environments
- attach logs, screen shots and/or exceptions if possible
- briefly summarize the steps you took to resolve or reproduce the problem

