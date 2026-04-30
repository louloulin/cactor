/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - BehaviorActor 单元测试
 */
package cactor.core.actor

import std.collection.*
import std.time.*
import cactor.core.message.*

/*
 * Mutable holder for tracking call state in lambdas.
 * Cangjie does not allow lambdas to capture var locals;
 * use a class with a var field instead.
 */
class BoolHolder {
    public var value: Bool
    public init() { this.value = false }
    public init(v: Bool) { this.value = v }
}

/*
 * Helper: check if two MessageResult values are the same using match.
 * Cangjie enums cannot use == or != directly.
 */
func messageResultEquals(a: MessageResult, b: MessageResult): Bool {
    match (a) {
        case MessageResult.Handled =>
            match (b) {
                case MessageResult.Handled => true
                case _ => false
            }
        case MessageResult.Unhandled =>
            match (b) {
                case MessageResult.Unhandled => true
                case _ => false
            }
        case MessageResult.Stop =>
            match (b) {
                case MessageResult.Stop => true
                case _ => false
            }
        case MessageResult.Restart =>
            match (b) {
                case MessageResult.Restart => true
                case _ => false
            }
        case MessageResult.Escalate =>
            match (b) {
                case MessageResult.Escalate => true
                case _ => false
            }
    }
}

@Test
func testBehaviorActorImpl_initialization() {
    let behavior = FunctionalBehavior({ msg, ctx => MessageResult.Handled })
    let actor = BehaviorActorImpl("test-actor", behavior)
    @Expect(actor.name, "test-actor")
    @Expect(actor.description.size > 0, true)
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

    let msg = TestMessage("probe")
    let ctx = BATestActorContext()
    let result = actor.receive(msg, ctx)
    @Expect(messageResultEquals(result, MessageResult.Unhandled), true)

    actor.unbecome()
    @Expect(actor.getBehaviorStackSize(), 0)

    let result2 = actor.receive(msg, ctx)
    @Expect(messageResultEquals(result2, MessageResult.Handled), true)
}

@Test
func testBehaviorActorImpl_multipleBecomeUnbecome() {
    let behavior1 = FunctionalBehavior({ msg, ctx => MessageResult.Handled })
    let actor = BehaviorActorImpl("test-actor", behavior1)

    let behavior2 = FunctionalBehavior({ msg, ctx => MessageResult.Unhandled })
    let behavior3 = FunctionalBehavior({ msg, ctx => MessageResult.Escalate })

    actor.become(behavior2)
    actor.become(behavior3)

    @Expect(actor.getBehaviorStackSize(), 2)

    let ctx = BATestActorContext()
    let msg = TestMessage("probe")

    let result1 = actor.receive(msg, ctx)
    @Expect(messageResultEquals(result1, MessageResult.Escalate), true)

    actor.unbecome()
    @Expect(actor.getBehaviorStackSize(), 1)

    let result2 = actor.receive(msg, ctx)
    @Expect(messageResultEquals(result2, MessageResult.Unhandled), true)

    actor.unbecome()
    @Expect(actor.getBehaviorStackSize(), 0)

    let result3 = actor.receive(msg, ctx)
    @Expect(messageResultEquals(result3, MessageResult.Handled), true)
}

@Test
func testBehaviorActorImpl_unbecomeOnEmptyStack() {
    let behavior = FunctionalBehavior({ msg, ctx => MessageResult.Handled })
    let actor = BehaviorActorImpl("test-actor", behavior)

    actor.unbecome()
    @Expect(actor.getBehaviorStackSize(), 0)

    let ctx = BATestActorContext()
    let msg = TestMessage("probe")
    let result = actor.receive(msg, ctx)
    @Expect(messageResultEquals(result, MessageResult.Handled), true)
}

@Test
func testBehaviorActorImpl_receiveIncrementsCount() {
    let behavior = FunctionalBehavior({ msg, ctx => MessageResult.Handled })
    let actor = BehaviorActorImpl("test-actor", behavior)

    let msg = TestMessage("test")
    let ctx = BATestActorContext()
    @Expect(actor.getReceivedCount(), 0)
    actor.receive(msg, ctx)
    @Expect(actor.getReceivedCount(), 1)
    actor.receive(msg, ctx)
    @Expect(actor.getReceivedCount(), 2)
}

@Test
func testFunctionalBehavior_handler() {
    let handled = BoolHolder()
    let behavior = FunctionalBehavior({ msg, ctx =>
        handled.value = true
        MessageResult.Handled
    })

    let msg = TestMessage("test")
    let ctx = BATestActorContext()
    let result = behavior.receive(msg, ctx)
    @Expect(handled.value, true)
    @Expect(messageResultEquals(result, MessageResult.Handled), true)
}

@Test
func testBehaviorSupport_receiveAll() {
    let received = BoolHolder()
    let behavior = BehaviorSupport.receiveAll({ msg, ctx =>
        received.value = true
        MessageResult.Handled
    })

    let msg = TestMessage("test")
    let ctx = BATestActorContext()
    let result = behavior.receive(msg, ctx)
    @Expect(received.value, true)
    @Expect(messageResultEquals(result, MessageResult.Handled), true)
}

@Test
func testBehaviorSupport_anyOf() {
    let firstCalled = BoolHolder()
    let secondCalled = BoolHolder()

    let first = FunctionalBehavior({ msg, ctx =>
        firstCalled.value = true
        MessageResult.Unhandled
    })

    let second = FunctionalBehavior({ msg, ctx =>
        secondCalled.value = true
        MessageResult.Handled
    })

    let behaviors = ArrayList<ActorBehavior>()
    behaviors.add(first)
    behaviors.add(second)

    let combined = BehaviorSupport.anyOf(behaviors)
    let msg = TestMessage("test")
    let ctx = BATestActorContext()
    let result = combined.receive(msg, ctx)

    @Expect(firstCalled.value, true)
    @Expect(secondCalled.value, true)
    @Expect(messageResultEquals(result, MessageResult.Handled), true)
}

@Test
func testBehaviorSupport_anyOf_stopsOnFirstHandler() {
    let firstCalled = BoolHolder()
    let secondCalled = BoolHolder()

    let first = FunctionalBehavior({ msg, ctx =>
        firstCalled.value = true
        MessageResult.Handled
    })

    let second = FunctionalBehavior({ msg, ctx =>
        secondCalled.value = true
        MessageResult.Handled
    })

    let behaviors = ArrayList<ActorBehavior>()
    behaviors.add(first)
    behaviors.add(second)

    let combined = BehaviorSupport.anyOf(behaviors)
    let msg = TestMessage("test")
    let ctx = BATestActorContext()
    let result = combined.receive(msg, ctx)

    @Expect(firstCalled.value, true)
    @Expect(secondCalled.value, false)
    @Expect(messageResultEquals(result, MessageResult.Handled), true)
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
    @Expect(config.timeout == Duration.second * 30, true)
    @Expect(config.repeatTimeout, true)
}

@Test
func testReceiveTimeoutConfig_withTimeoutOnce() {
    let config = ReceiveTimeoutConfig.withTimeoutOnce(Duration.second * 60)
    @Expect(config.enabled, true)
    @Expect(config.timeout == Duration.second * 60, true)
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

    public func messageType(): String { "TestMessage" }
}

// Mock ActorContext - 实现 cactor.core.actor.ActorContext
class BATestActorContext <: ActorContext {
    private let selfRef: BATestActorRef
    private let systemRef: BATestActorSystem

    public init() {
        this.systemRef = BATestActorSystem()
        this.selfRef = BATestActorRef(systemRef)
    }

    public func sender(): ActorRef { selfRef }
    public func self(): ActorRef { selfRef }
    public func parent(): ActorRef { selfRef }
    public func children(): Array<ActorRef> { emptyActorRefArray() }
    public func child(name: String): Option<ActorRef> { None }
    public func actorOf(props: Props<Actor>, name: String): ActorRef { selfRef }
    public func actorOf(props: Props<Actor>): ActorRef { selfRef }
    public func watch(actorRef: ActorRef): Unit {}
    public func unwatch(actorRef: ActorRef): Unit {}
    public func getActorSystem(): ActorSystem { systemRef }
    public func setReceiveTimeout(timeout: Duration): Unit {}
    public func receiveTimeout(): Duration { Duration.second * 0 }
    public func stop(): Unit {}
    public func stop(actorRef: ActorRef): Unit {}
}

// Helper to create an empty Array<ActorRef> without initializer
func emptyActorRefArray(): Array<ActorRef> {
    let list = ArrayList<ActorRef>()
    list.toArray()
}

// Mock ActorRef
class BATestActorRef <: ActorRef {
    private let pathValue: ActorPath

    public init(system: BATestActorSystem) {
        this.pathValue = ActorPath(system.name(), "/test/mock")
    }

    public prop path: ActorPath {
        get() { pathValue }
    }

    public func tell(message: Message): Unit {}
    public func tell(message: Message, sender: Option<String>): Unit {}
    public func equals(other: ActorRef): Bool { pathValue.toString() == other.path.toString() }
    public func hashCode(): Int32 { 0 }
}

// Mock ActorSystem - implements cactor.core.actor.ActorSystem (empty interface)
class BATestActorSystem <: ActorSystem {
    private let systemName: String = "test-system"

    public init() {}

    public func name(): String { systemName }
}
