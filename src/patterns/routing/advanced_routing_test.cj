/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 高级路由模式单元测试
 */
package cactor.patterns.routing

import std.collection.*
import std.time.*
import std.sync.*
import cactor.core.message.Message
import cactor.core.actor.{ActorRef, ActorPath}

/**
 * TestMessage - 测试用消息
 */
class TestRoutingMessage <: Message {
    public let content: String

    public init(content: String) {
        this.content = content
    }

    public func messageType(): String {
        "TestRoutingMessage"
    }
}

/**
 * TestResponseMessage - 测试用响应消息
 */
class TestResponseMessage <: Message {
    public let value: String

    public init(value: String) {
        this.value = value
    }

    public func messageType(): String {
        "TestResponseMessage"
    }
}

// === AtomicBoolean Tests ===

@Test
func testAtomicBoolean_init() {
    let atomic = AtomicBoolean(false)
    @Expect(atomic.load(), false)

    let atomic2 = AtomicBoolean(true)
    @Expect(atomic2.load(), true)
}

@Test
func testAtomicBoolean_store() {
    let atomic = AtomicBoolean(false)
    atomic.store(true)
    @Expect(atomic.load(), true)

    atomic.store(false)
    @Expect(atomic.load(), false)
}

@Test
func testAtomicBoolean_getAndSet() {
    let atomic = AtomicBoolean(false)
    let old = atomic.getAndSet(true)
    @Expect(old, false)
    @Expect(atomic.load(), true)
}

// === AtomicReference Tests ===

@Test
func testAtomicReference_init() {
    let ref = AtomicReference<Int64>(42)
    @Expect(ref.load(), 42)
}

@Test
func testAtomicReference_store() {
    let ref = AtomicReference<Int64>(0)
    ref.store(100)
    @Expect(ref.load(), 100)
}

@Test
func testAtomicReference_compareAndSet() {
    let ref = AtomicReference<Int64>(42)
    let success = ref.compareAndSet(42, 100)
    @Expect(success, true)
    @Expect(ref.load(), 100)

    let fail = ref.compareAndSet(42, 200)
    @Expect(fail, false)
    @Expect(ref.load(), 100)
}

// === FutureResult Tests ===

@Test
func testFutureResult_creation() {
    let result = FutureResult<String>()
    @Expect(result.isDone(), false)
}

// === RecipientList Tests ===

@Test
func testRecipientList_empty() {
    let list = RecipientList()
    @Expect(list.size(), 0)
}

@Test
func testRecipientList_add() {
    let list = RecipientList()
    let mockRef = MockActorRef("test1")

    list.addRecipient(mockRef)
    @Expect(list.size(), 1)

    // 添加重复的应该忽略
    list.addRecipient(mockRef)
    @Expect(list.size(), 1)
}

@Test
func testRecipientList_remove() {
    let list = RecipientList()
    let ref1 = MockActorRef("test1")
    let ref2 = MockActorRef("test2")

    list.addRecipient(ref1)
    list.addRecipient(ref2)
    @Expect(list.size(), 2)

    list.removeRecipient(ref1)
    @Expect(list.size(), 1)

    let recipients = list.getRecipients()
    @Expect(recipients.size, 1)
    @Expect(recipients[0].equals(ref2), true)
}

@Test
func testRecipientList_withFilter() {
    let list = RecipientList()
    let ref = MockActorRef("test")

    list.addRecipient(ref)
    list.withFilter({ msg =>
        msg.messageType() == "TestRoutingMessage"
    })

    // 过滤器设置成功
    let recipients = list.getRecipients()
    @Expect(recipients.size, 1)
}

@Test
func testRecipientList_updateRecipients() {
    let list = RecipientList()
    let ref1 = MockActorRef("test1")
    let ref2 = MockActorRef("test2")
    let ref3 = MockActorRef("test3")

    list.addRecipient(ref1)
    @Expect(list.size(), 1)

    list.updateRecipients([ref2, ref3])
    @Expect(list.size(), 2)

    let recipients = list.getRecipients()
    @Expect(recipients[0].equals(ref2), true)
    @Expect(recipients[1].equals(ref3), true)
}

@Test
func testRecipientList_clear() {
    let list = RecipientList()
    let ref = MockActorRef("test")

    list.addRecipient(ref)
    @Expect(list.size(), 1)

    list.clear()
    @Expect(list.size(), 0)
}

// === TailChopping Tests ===

@Test
func testTailChopping_empty() {
    let chopper = TailChopping()
    @Expect(chopper.size(), 0)
}

@Test
func testTailChopping_withRecipients() {
    let ref1 = MockActorRef("test1")
    let ref2 = MockActorRef("test2")

    let chopper = TailChopping([ref1, ref2])
    @Expect(chopper.size(), 2)
}

@Test
func testTailChopping_addRecipient() {
    let chopper = TailChopping()
    let ref = MockActorRef("test")

    chopper.addRecipient(ref)
    @Expect(chopper.size(), 1)
}

@Test
func testTailChopping_removeRecipient() {
    let ref1 = MockActorRef("test1")
    let ref2 = MockActorRef("test2")

    let chopper = TailChopping([ref1, ref2])
    @Expect(chopper.size(), 2)

    chopper.removeRecipient(ref1)
    @Expect(chopper.size(), 1)
}

@Test
func testTailChopping_withInterval() {
    let ref = MockActorRef("test")
    let chopper = TailChopping([ref])

    chopper.withInterval(Duration.millisecond * 100)
    // 验证方法链式调用
    @Expect(chopper.size(), 1)
}

@Test
func testTailChopping_withTimeout() {
    let ref = MockActorRef("test")
    let chopper = TailChopping([ref])

    chopper.withTimeout(Duration.second * 5)
    @Expect(chopper.size(), 1)
}

@Test
func testTailChopping_size() {
    let ref1 = MockActorRef("test1")
    let ref2 = MockActorRef("test2")
    let ref3 = MockActorRef("test3")

    let chopper = TailChopping([ref1, ref2, ref3])
    @Expect(chopper.size(), 3)
}

// === ScatterGatherFirstCompleted Tests ===

@Test
func testScatterGatherFirstCompleted_creation() {
    let sg = ScatterGatherFirstCompleted()
    @Expect(sg != None, true)
}

@Test
func testScatterGatherFirstCompleted_withTimeout() {
    let sg = ScatterGatherFirstCompleted()
    sg.withTimeout(Duration.second * 10)
    // 验证方法链式调用
    @Expect(sg != None, true)
}

@Test
func testScatterGatherFirstCompleted_emptyRoutees() {
    let sg = ScatterGatherFirstCompleted()
    let result = sg.scatterGather([], TestRoutingMessage("test"), None)

    @Expect(result.isDone(), true)
}

@Test
func testScatterGatherFirstCompleted_withRoutees() {
    let ref1 = MockActorRef("test1")
    let ref2 = MockActorRef("test2")

    let sg = ScatterGatherFirstCompleted()
    let result = sg.scatterGather([ref1, ref2], TestRoutingMessage("test"), None)

    @Expect(result != None, true)
}

// === MockActorRef - 测试用 ActorRef ===

class MockActorRef <: ActorRef {
    private let name: String
    private let mockPath: ActorPath
    private let sentMessages: ArrayList<Message>

    public init(name: String) {
        this.name = name
        this.mockPath = ActorPath("mock", "/${name}")
        this.sentMessages = ArrayList<Message>()
    }

    public prop path: ActorPath {
        get() { mockPath }
    }

    public func tell(message: Message): Unit {
        sentMessages.add(message)
    }

    public func tell(message: Message, sender: Option<String>): Unit {
        sentMessages.add(message)
    }

    public func equals(other: ActorRef): Bool {
        match (other) {
            case mock: MockActorRef => name == mock.name
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        Int32(name.hashCode())
    }

    public func getSentMessages(): ArrayList<Message> {
        sentMessages
    }

    public func clearSentMessages(): Unit {
        sentMessages.clear()
    }
}
