# ActorBench

ActorBench is a suite of microbenchmarks designed to measure various aspects of an actor programming framework. Currently, implementations exist for:

- Akka/Scala
- Theater/Swift

See `READMD.md` under each implementation's directory for usage instructions.

# Benchmarks

## Ring

This is an implementation of the Ring benchmark, as described in [*Programming Erlang*](http://pragprog.com/book/jaerlang/programming-erlang), for which there many solutions on the web. N actors are created in a ring. A message is sent around the ring for M times so that a total of N * M messages get sent. At all times, there is only one message in flight.

Purpose: actor scheduling overhead

## BusyRing

This modified version of the Ring benchmark sends M messages along a ring of N actors. Each message travels along the ring exactly once.

Purpose: throughput

## Fork

Starting from a root actor, each actor creates two child actors and form a binary tree. The <depth> parameter specifies the maximum depth of the tree.

Purpose: actor creation time

## TreeMsg

This benchmark creates an actor tree and then send messages from root to leaves. The tree creation process is the same as in Fork. After actor tree is created, root actor sends <num_msg> messages to its children. Non-leaf nodes simply forward messages to their children, and leaf nodes send ACKs back to root node. If root node receives enough ACKs, it terminates the program.

Purpose: efficiency of actor lookup process

## Pipeline

This benchmark simulates a 3-stage message processing pipeline. The pipeline looks like this: downloader -> indexer -> writer. In the beginning, <num_request> request messages are sent to downloader. Each request message contains a string "Requested ". Downlaoder substitutes "Requested" with "Downloaded", and later indexer changes "Downloaded" to "Indexed", and finally writer changes "Indexed" to "Written".

Purpose: throughput of stateless actors

## Chameneos

This is an implementation of the [Chameneos concurrency benchmark](https://benchmarksgame.alioth.debian.org/u64q/chameneosredux-description.html#chameneosredux). Two kinds of actor are created, one Mall actor and N Chameneos actors (N > 2). Chameneos meet other Chameneos at the Mall. A Chameneos indicates its wish to meet another Chameneos by sending a Meeting message to the Mall, which will either:

1. put that Chameneos in a waiting slot if there is no other Chameneos waiting to meet, or
2. forward that Meeting message to the awaiting Chameneos.

When two Chameneos meet, they change their colors (internal state) and then resume sending more Meeting requests to the Mall. The Mall can host at most M Chameneos at a time. If the limit is reached, the Mall tells all incoming Chameneos to stop. After getting exit confirmation from each Chameneos, the program stops.

Purpose: throughput of stateful actors

## Calculator

A Master actor accepts <num_expressions> requests and forward them to its workers randomly. The number of workers is specified by <num_workers>. When a worker receives the forwarded request from master, it generates a random arithmetic expression, computes the result, and increases the counter. Each random arithmetic expression contains <num_operators> basic arithmetic operators (e.g. +, -, \*, /).

Purpose: scheduling of master/worker model
