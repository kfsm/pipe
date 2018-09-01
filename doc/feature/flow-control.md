# Pipe Flow Control and Overloads

The `pipes` library encourage asynchronous communication to build an actor based system. The synchronous communication is only advertised when request enters to the system. The asynchronous communication suffers 
from overloads when incoming rate is slow then processing rate.

The subject of traffic congestions and flow control is well research in traditional networking. They are using windows, tokens, back propagations, etc. The `pipes` library implements credit-based, link-by-link technique, which is borrowed from flow-controlled ATM networks. In turn, this old technique for controlling floods. Dams on a river for holding floods are analogous to network buffers, process mailboxes for holding excessive data.

> To control floods, dams are often built in series along a river, so that an upstream dam can share the load for any downstream dam. Whenever a dam is becoming full, its upstream dams are notified to hold additional water. In this way, all the upstream dams can help reduce flooding at a downstream congestion point, and each upstream dam can help prevent flooding at all downstream congestion points. The capacity of every dam is efficiently used.

The `pipes` library uses a credits for each communication. Each time the stage forwards message to side-b it decreases its current credit balance of link by one. The stage suspends its activity when balance exhausted. The stage needs to request new credits for link from the receiver before communication is resumed. The nature of FIFO queues grantees that credit request is delivered to receiver when mailbox congestion is resolved. The protocol automatically propagates congestion signal to upstream stages, once they consumes credits.


Let's illustrated the protocol with two stages: `X` and `Y`. Stage `X` receives a message from its side `a`, processes it and egress to its side `b`, which is bound to side `a` of stage `Y`. This process is recursively repeated. This is a logical communication, they are Erlang processes with message queues `MQx` and `MQy` on "physical" layer. The pipe protocol labels each message with source address so that recipient is able to determine originator side.  


```      MQx                              MQy
         |_|                              |_|
         |c|                              |_|
         |_|                              |c|
         |_|                              |_|
     +---------+                      +---------+                      +---------+
     |         |                      |         |                      |         |
... -|a   X   b|----------------------|a   Y   b|- ...                 |   Sup   |
     |         |                      |         |                      |         |
     +---------+                      +---------+                      +---------+
          ^                                ^                                |
          |                                |                                |
          +--------------------------------+--------------------------------+
                                        capacity 
```

The flow control management protocol is started with negotiation phase. Each stage is assigned with capacity and credits to each side. The capacity of stages is fixed for entire pipeline by supervisor process (all stages in pipeline has same capacity) but each stage sets random amount of credits. 

Ingress message on side `a` of `X` stage causes a stage to make a work and egress results to side `b`. The flow control protocol consumes credits associated with side `b`. Stage `X` send the credit request `c` to stage `Y` once the credit balance is exhausted. The stage blocks execution until stage `Y` respond with positive credit balance. Same protocol is executed when communication occurs along side `a`.

The given protocol is under threat of dead lock when stage `X` requests credit from `Y` and `Y` request credits from `X` because consumption of message queue is blocked until credit response is received. Deadlocks are resolved using priority queues, all credit request / response signaling goes with higher priority then data messages. The state do not block reception and handling of credit requests. It is implemented with selective receive feature at Erlang.

References

1. [Credit-based Flow Control](https://www.nap.edu/read/5769/chapter/4)

