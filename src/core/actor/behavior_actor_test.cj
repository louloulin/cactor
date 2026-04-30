/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - BehaviorActor 单元测试
 */
package cactor.core.actor

import std.collection.*
import std.time.*
import cactor.core.message.*

@Test
func testBehaviorActorImpl_initialization() {
    let behavior = FunctionalBehavior({ msg, ctx => MessageResult.Handled })
    let actor = BehaviorActorImpl("test-actor", behavior)
    @Expect(actor.name, "test-actor")
    @Expect(actor.currentBehavior() !== None, true)
    @Expect(actor.getBehaviorStackSize(), 0)
    @Expect(actor.getReceivedCount(), 0)
}

@Test
func testBehaviorActorImpl_becomeUnbecome() {
    let initialBehavior = FunctionalBehavior({ msg, ctx => MessageResult.Handled })
    let actor = BehaviorActorImpl("test-actor", initialBehavior)

    let newBehavior = FunctionalBehavior({ msg, ctx => MessageResult.Unhandled })
    actor.become(newBehavior)

    @Expect(actor.getBehaviorStackSize(), 1)
    @Expect(actor.currentBehavior() === newBehavior, true)

    actor.unbecome()
    @Expect(actor.getBehaviorStackSize(), 0)
    @Expect(actor.currentBehavior() === initialBehavior, true)
}

@Test
func testBehaviorActorImpl_multipleBecomeUnbecome() {
    let behavior1 = FunctionalBehavior({ msg, ctx => MessageResult.Handled })
    let actor = BehaviorActorImpl("test-actor", behavior1)

    let behavior2 = FunctionalBehavior({ msg, ctx => MessageResult.Unhandled })
    let behavior3 = FunctionalBehavior({ msg, ctx => MessageResult.Handled })

    actor.become(behavior2)
    actor.become(behavior3)

    @Expect(actor.getBehaviorStackSize(), 2)

    actor.unbecome()
    @Expect(actor.getBehaviorStackSize(), 1)
    @Expect(actor.currentBehavior() === behavior2, true)

    actor.unbecome()
    @Expect(actor.getBehaviorStackSize(), 0)
    @Expect(actor.currentBehavior() === behavior1, true)
}

@Test
func testBehaviorActorImpl_unbecomeOnEmptyStack() {
    let behavior = FunctionalBehavior({ msg, ctx => MessageResult.Handled })
    let actor = BehaviorActorImpl("test-actor", behavior)

    actor.unbecome()
    @Expect(actor.getBehaviorStackSize(), 0)
    @Expect(actor.currentBehavior() === behavior, true)
}

@Test
func testBehaviorActorImpl_receiveIncrementsCount() {
    let behavior = FunctionalBehavior({ msg, ctx => MessageResult.Handled })
    let actor = BehaviorActorImpl("test-actor", behavior)

    let msg = TestMessage("test")
    @Expect(actor.getReceivedCount(), 0)
    actor.receive(msg, ActorContextMock())
    @Expect(actor.getReceivedCount(), 1)
    actor.receive(msg, ActorContextMock())
    @Expect(actor.getReceivedCount(), 2)
}

@Test
func testFunctionalBehavior_handler() {
    var handled = false
    let behavior = FunctionalBehavior({ msg, ctx =>
        handled = true
        MessageResult.Handled
    })

    let msg = TestMessage("test")
    let result = behavior.receive(msg, ActorContextMock())
    @Expect(handled, true)
    @Expect(result === MessageResult.Handled, true)
}

@Test
func testBehaviorSupport_receiveAll() {
    var received = false
    let behavior = BehaviorSupport.receiveAll({ msg, ctx =>
        received = true
        MessageResult.Handled
    })

    let msg = TestMessage("test")
    let result = behavior.receive(msg, ActorContextMock())
    @Expect(received, true)
    @Expect(result === MessageResult.Handled, true)
}

@Test
func testBehaviorSupport_anyOf() {
    var firstCalled = false
    var secondCalled = false

    let first = FunctionalBehavior({ msg, ctx =>
        firstCalled = true
        MessageResult.Unhandled
    })

    let second = FunctionalBehavior({ msg, ctx =>
        secondCalled = true
        MessageResult.Handled
    })

    let behaviors = ArrayList<ActorBehavior>()
    behaviors.add(first)
    behaviors.add(second)

    let combined = BehaviorSupport.anyOf(behaviors)
    let msg = TestMessage("test")
    let result = combined.receive(msg, ActorContextMock())

    @Expect(firstCalled, true)
    @Expect(secondCalled, true)
    @Expect(result === MessageResult.Handled, true)
}

@Test
func testBehaviorSupport_anyOf_stopsOnFirstHandler() {
    var firstCalled = false
    var secondCalled = false

    let first = FunctionalBehavior({ msg, ctx =>
        firstCalled = true
        MessageResult.Handled
    })

    let second = FunctionalBehavior({ msg, ctx =>
        secondCalled = true
        MessageResult.Handled
    })

    let behaviors = ArrayList<ActorBehavior>()
    behaviors.add(first)
    behaviors.add(second)

    let combined = BehaviorSupport.anyOf(behaviors)
    let msg = TestMessage("test")
    let result = combined.receive(msg, ActorContextMock())

    @Expect(firstCalled, true)
    @Expect(secondCalled, false)
    @Expect(result === MessageResult.Handled, true)
}

@Test
func testStashingActor_stashUnstash() {
    let actor = StashingActor("stashing-actor")
    @Expect(actor.stashSize(), 0)

    let msg1 = TestMessage("msg1")
    let msg2 = TestMessage("msg2")

    actor.stash(msg1)
    actor.stash(msg2)
    @Expect(actor.stashSize(), 2)

    actor.unstash()
    @Expect(actor.isUnstashing(), true)

    let messages = actor.unstashAll()
    @Expect(messages.size, 2)
    @Expect(actor.stashSize(), 0)
    @Expect(actor.isUnstashing(), false)
}

@Test
func testStashingActor_unstashAll() {
    let actor = StashingActor("stashing-actor")

    actor.stash(TestMessage("msg1"))
    actor.stash(TestMessage("msg2"))
    actor.stash(TestMessage("msg3"))

    let messages = actor.unstashAll()
    @Expect(messages.size, 3)
    @Expect(actor.stashSize(), 0)
}

@Test
func testReceiveTimeoutConfig_disabled() {
    let config = ReceiveTimeoutConfig.disabled()
    @Expect(config.enabled, false)
}

@Test
func testReceiveTimeoutConfig_withTimeout() {
    let config = ReceiveTimeoutConfig.withTimeout(Duration.second * 30)
    @Expect(config.enabled, true)
    @Expect(config.timeout === Duration.second * 30, true)
    @Expect(config.repeatTimeout, true)
}

@Test
func testReceiveTimeoutConfig_withTimeoutOnce() {
    let config = ReceiveTimeoutConfig.withTimeoutOnce(Duration.second * 60)
    @Expect(config.enabled, true)
    @Expect(config.timeout === Duration.second * 60, true)
    @Expect(config.repeatTimeout, false)
}

/*
 * 测试辅助类和消息
 */

// 测试用消息
public class TestMessage <: Message {
    public let content: String

    public init(content: String) {
        this.content = content
    }

    public func getType(): String { "TestMessage" }
    public func getPayload(): String { "TestMessage(${content})" }
    public func messageType(): String { "TestMessage" }
}

// Mock ActorContext
class ActorContextMock <: ActorContext {
    public init() {}

    public func sender(): ActorRef { ActorRefMock() }
    public func self(): ActorRef { ActorRefMock() }
    public func parent(): ActorRef { ActorRefMock() }
    public func children(): Array<ActorRef> { Array<ActorRef>(0) }
    public func child(name: String): Option<ActorRef> { None }
    public func actorOf(props: Props<Actor>, name: String): ActorRef { ActorRefMock() }
    public func actorOf(props: Props<Actor>): ActorRef { ActorRefMock() }
    public func watch(actorRef: ActorRef): Unit {}
    public func unwatch(actorRef: ActorRef): Unit {}
    public func system(): ActorSystem { ActorSystemMock() }
    public func setReceiveTimeout(timeout: Duration): Unit {}
    public func receiveTimeout(): Duration { Duration.second * 0 }
    public func stop(): Unit {}
    public func stop(actorRef: ActorRef): Unit {}
}

// Mock ActorRef
class ActorRefMock <: ActorRef {
    public init() {}

    public func tell(message: Message, senderOption: ActorRef): Unit {}
    public func path(): String { "/mock" }
    public func isLocal(): Bool { true }
}

// Mock ActorSystem
class ActorSystemMock <: ActorSystem {
    public init() {}

    public func actorOf(props: Props<Actor>, name: String): ActorRef { ActorRefMock() }
    public func actorOf(props: Props<Actor>): ActorRef { ActorRefMock() }
    public func actorSelection(path: String): ActorSelection { ActorSelectionMock() }
    public func terminate(): Unit {}
    public func whenTerminated(): SimpleFuture<Unit> { SimpleFutureMock() }
    public func eventStream(): EventBus { EventBusMock() }
    public func log(): ActorLog { ActorLogMock() }
    public func startTime(): Int64 { 0 }
    public func isTerminated(): Bool { false }
    public func name(): String { "mock-system" }
}

// Mock SimpleFuture
class SimpleFutureMock <: SimpleFuture<Unit> {
    public init() {}

    public func get(timeout: Duration): Option<Unit> { Some(Unit) }
    public func isDone(): Bool { true }
}

// Mock EventBus
class EventBusMock <: EventBus {
    public init() {}

    public func publish(event: Any): Unit {}
    public func subscribe(subscriber: ActorRef, eventType: String): Bool { false }
    public func unsubscribe(subscriber: ActorRef, eventType: String): Bool { false }
    public func subscriberCount(eventType: String): Int64 { 0 }
}

// Mock ActorLog
class ActorLogMock <: ActorLog {
    public init() {}

    public func debug(message: String): Unit {}
    public func info(message: String): Unit {}
    public func warning(message: String): Unit {}
    public func error(message: String): Unit {}
    public func error(cause: Exception, message: String): Unit {}
}

// Mock ActorSelection
class ActorSelectionMock <: ActorSelection {
    public init() {}

    public func tell(message: Message, senderOption: ActorRef): Unit {}
    public func resolveOne(timeout: Duration): Option<ActorRef> { None }
}
