/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - BalancingDispatcher 单元测试
 */
package cactor.runtime.dispatcher

import std.collection.*
import std.sync.*
import cactor.core.actor.{ActorRef, ActorPath}
import cactor.core.message.{Message, Envelope}
import cactor.runtime.dispatcher.advanced.Priority

/*
 * 测试辅助类
 */
class BDTestActorRef <: ActorRef {
    private let pathValue: ActorPath
    private let received: ArrayList<Message>
    private let name: String

    public init(name: String) {
        this.name = name
        this.pathValue = ActorPath("test-system", "/test/${name}")
        this.received = ArrayList<Message>()
    }

    public prop path: ActorPath {
        get() { pathValue }
    }

    public func tell(message: Message): Unit {
        received.add(message)
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        received.add(message)
    }

    public func equals(other: ActorRef): Bool {
        pathValue.toString() == other.path.toString()
    }

    public func hashCode(): Int32 { 0 }

    public func getReceived(): Array<Message> { received.toArray() }

    public func getReceivedCount(): Int64 { Int64(received.size) }

    public func getName(): String { name }
}

class BDTestMessage <: Message {
    private let id: Int64

    public init(id: Int64) {
        this.id = id
    }

    public func messageType(): String { "BDTestMessage" }

    public func getId(): Int64 { id }
}

// === BalancingDispatcher Tests ===

@Test
func testBalancingDispatcher_init_defaultStrategy() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    @Expect(dispatcher.workerCount(), 0)
    @Expect(dispatcher.strategyName(), "RoundRobin")
    @Expect(dispatcher.isRunning(), false)
}

@Test
func testBalancingDispatcher_init_leastLoadedStrategy() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.LeastLoaded)
    @Expect(dispatcher.strategyName(), "LeastLoaded")
}

@Test
func testBalancingDispatcher_init_randomStrategy() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.Random)
    @Expect(dispatcher.strategyName(), "Random")
}

@Test
func testBalancingDispatcher_addWorker() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let ref1 = BDTestActorRef("worker1")
    let ref2 = BDTestActorRef("worker2")

    dispatcher.addWorker(ref1)
    @Expect(dispatcher.workerCount(), 1)

    dispatcher.addWorker(ref2)
    @Expect(dispatcher.workerCount(), 2)
}

@Test
func testBalancingDispatcher_removeWorker() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let ref1 = BDTestActorRef("worker1")
    let ref2 = BDTestActorRef("worker2")

    dispatcher.addWorker(ref1)
    dispatcher.addWorker(ref2)
    @Expect(dispatcher.workerCount(), 2)

    let removed = dispatcher.removeWorker(ref1)
    @Expect(removed, true)
    @Expect(dispatcher.workerCount(), 1)
}

@Test
func testBalancingDispatcher_removeWorker_notFound() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let ref = BDTestActorRef("worker1")

    dispatcher.addWorker(ref)
    // First removal succeeds
    let removed1 = dispatcher.removeWorker(ref)
    @Expect(removed1, true)
    @Expect(dispatcher.workerCount(), 0)
    // Second removal fails (already removed)
    let removed2 = dispatcher.removeWorker(ref)
    @Expect(removed2, false)
}

@Test
func testBalancingDispatcher_selectWorker_noWorkers() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let result = dispatcher.selectWorker()
    match (result) {
        case None => @Expect(true, true)
        case Some(_) => @Expect(false, true)
    }
}

@Test
func testBalancingDispatcher_selectWorker_roundRobin() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let ref1 = BDTestActorRef("worker1")
    let ref2 = BDTestActorRef("worker2")
    dispatcher.addWorker(ref1)
    dispatcher.addWorker(ref2)

    // RoundRobin should alternate between workers
    let sel1 = dispatcher.selectWorker()
    let sel2 = dispatcher.selectWorker()

    match (sel1) {
        case Some(r) => @Expect(true, true)
        case None => @Expect(false, true)
    }
    match (sel2) {
        case Some(r) => @Expect(true, true)
        case None => @Expect(false, true)
    }
}

@Test
func testBalancingDispatcher_selectWorker_leastLoaded() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.LeastLoaded)
    let worker1 = BDTestActorRef("worker1")
    let worker2 = BDTestActorRef("worker2")
    dispatcher.addWorker(worker1)
    dispatcher.addWorker(worker2)

    // The least loaded strategy should be able to select workers
    let result = dispatcher.selectWorker()
    match (result) {
        case Some(r) => @Expect(true, true)
        case None => @Expect(false, true)
    }
}

@Test
func testBalancingDispatcher_selectWorker_random() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.Random)
    let ref1 = BDTestActorRef("worker1")
    let ref2 = BDTestActorRef("worker2")
    dispatcher.addWorker(ref1)
    dispatcher.addWorker(ref2)

    // Random should still return a valid worker
    let result = dispatcher.selectWorker()
    match (result) {
        case Some(r) => @Expect(true, true)
        case None => @Expect(false, true)
    }
}

@Test
func testBalancingDispatcher_startStop() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)

    @Expect(dispatcher.isRunning(), false)
    dispatcher.start()
    @Expect(dispatcher.isRunning(), true)
    dispatcher.stop()
    @Expect(dispatcher.isRunning(), false)
}

@Test
func testBalancingDispatcher_dispatch_withWorkers() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let worker1 = BDTestActorRef("worker1")
    let worker2 = BDTestActorRef("worker2")
    dispatcher.addWorker(worker1)
    dispatcher.addWorker(worker2)

    let msg = BDTestMessage(Int64(1))
    let envelope = Envelope(msg, None)
    let fallback = BDTestActorRef("fallback")

    dispatcher.dispatch(envelope, fallback)

    // One of the workers should have received the message
    let totalReceived = worker1.getReceivedCount() + worker2.getReceivedCount()
    @Expect(totalReceived, 1)
}

@Test
func testBalancingDispatcher_dispatch_noWorkers_fallback() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)

    let msg = BDTestMessage(Int64(1))
    let envelope = Envelope(msg, None)
    let fallback = BDTestActorRef("fallback")

    dispatcher.dispatch(envelope, fallback)

    // Without workers, fallback should receive the message
    @Expect(fallback.getReceivedCount(), 1)
}

@Test
func testBalancingDispatcher_dispatchBatch() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let worker1 = BDTestActorRef("worker1")
    let worker2 = BDTestActorRef("worker2")
    dispatcher.addWorker(worker1)
    dispatcher.addWorker(worker2)

    let envelopesList = ArrayList<Envelope>()
    envelopesList.add(Envelope(BDTestMessage(Int64(0)), None))
    envelopesList.add(Envelope(BDTestMessage(Int64(1)), None))
    envelopesList.add(Envelope(BDTestMessage(Int64(2)), None))
    let envelopes = envelopesList.toArray()
    let emptyActorRefs = ArrayList<ActorRef>().toArray()

    dispatcher.dispatchBatch(envelopes, emptyActorRefs)

    let totalReceived = worker1.getReceivedCount() + worker2.getReceivedCount()
    @Expect(totalReceived, 3)
}

@Test
func testBalancingDispatcher_dispatchWithPriority() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let worker1 = BDTestActorRef("worker1")
    dispatcher.addWorker(worker1)

    let msg = BDTestMessage(Int64(1))
    let envelope = Envelope(msg, None)
    let fallback = BDTestActorRef("fallback")

    dispatcher.dispatchWithPriority(envelope, fallback, Priority.Normal)

    @Expect(worker1.getReceivedCount(), 1)
}

@Test
func testBalancingDispatcher_workerStats() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let ref = BDTestActorRef("worker1")
    dispatcher.addWorker(ref)

    let stats = dispatcher.getWorkerStats()
    @Expect(stats.size, 1)
    @Expect(stats[0].getActorRef().equals(ref), true)
    @Expect(stats[0].getPendingCount(), 0)
    @Expect(stats[0].getProcessedCount(), 0)
}

@Test
func testBalancingDispatcher_workerStats_pendingProcessed() {
    let stats = WorkerStats(BDTestActorRef("test"))

    stats.incrementPending()
    stats.incrementPending()
    @Expect(stats.getPendingCount(), 2)

    stats.decrementPending()
    @Expect(stats.getPendingCount(), 1)
    @Expect(stats.getProcessedCount(), 1)
}

@Test
func testBalancingDispatcher_getPendingCount() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let ref1 = BDTestActorRef("worker1")
    let ref2 = BDTestActorRef("worker2")
    dispatcher.addWorker(ref1)
    dispatcher.addWorker(ref2)

    @Expect(dispatcher.getPendingCount(), 0)
    @Expect(dispatcher.getProcessedCount(), 0)

    let stats = dispatcher.getWorkerStats()
    stats[0].incrementPending()
    stats[1].incrementPending()
    stats[1].incrementPending()

    @Expect(dispatcher.getPendingCount(), 3)
}

@Test
func testBalancingDispatcher_getProcessedCount() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let ref = BDTestActorRef("worker1")
    dispatcher.addWorker(ref)

    let stats = dispatcher.getWorkerStats()
    stats[0].incrementPending()
    stats[0].decrementPending()

    @Expect(dispatcher.getProcessedCount(), 1)
}

@Test
func testBalancingDispatcher_getPerformanceStats() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let ref = BDTestActorRef("worker1")
    dispatcher.addWorker(ref)

    let stats = dispatcher.getPerformanceStats()
    @Expect(stats.size > 0, true)
}

@Test
func testBalancingDispatcher_getConfig() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let config = dispatcher.getConfig()
    @Expect(config.name.size > 0, true)
}

@Test
func testBalancingDispatcher_roundRobinDistribution() {
    let dispatcher = BalancingDispatcher(BalanceStrategy.RoundRobin)
    let worker1 = BDTestActorRef("worker1")
    let worker2 = BDTestActorRef("worker2")
    dispatcher.addWorker(worker1)
    dispatcher.addWorker(worker2)

    // Dispatch 10 messages
    for (i in 0..10) {
        let envelope = Envelope(BDTestMessage(Int64(i)), None)
        let fallback = BDTestActorRef("fallback")
        dispatcher.dispatch(envelope, fallback)
    }

    let w1 = worker1.getReceivedCount()
    let w2 = worker2.getReceivedCount()
    let total = w1 + w2
    @Expect(total, 10)
    // RoundRobin with 2 workers should split ~5/5
    @Expect(w1, 5)
    @Expect(w2, 5)
}
