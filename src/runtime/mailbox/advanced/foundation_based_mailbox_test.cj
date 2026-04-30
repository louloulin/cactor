/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Foundation邮箱单元测试
 * 测试基于Foundation队列的所有邮箱实现
 */
package cactor.runtime.mailbox.advanced

import std.collection.*
import std.time.*
import cactor.core.message.{Message, Envelope, StringMessage}
import cactor.core.config.{MailboxConfig, MailboxType}
import cactor.runtime.mailbox.Mailbox

// === 测试辅助类 ===

/**
 * 测试用消息
 */
public class TestMessage <: Message {
    private let id: Int64
    private let content: String
    private let priorityValue: Int32

    public init(id: Int64, content: String, priorityValue: Int32) {
        this.id = id
        this.content = content
        this.priorityValue = priorityValue
    }

    public init(id: Int64, content: String) {
        this.id = id
        this.content = content
        this.priorityValue = 0
    }

    public func messageType(): String { "TestMessage" }

    public func getId(): Int64 { id }

    public func getContent(): String { content }

    public func priority(): Int32 { priorityValue }

    public func messageId(): String { "msg-${id}" }
}

/**
 * 创建测试信封（无优先级）
 */
func createTestEnvelope(id: Int64, content: String): Envelope {
    let msg = TestMessage(id, content)
    Envelope(msg, Some("test-sender"))
}

/**
 * 创建测试信封（带优先级）
 */
func createTestEnvelopeWithPriority(id: Int64, content: String, priority: Int32): Envelope {
    let msg = TestMessage(id, content, priority)
    Envelope(msg, Some("test-sender"))
}

// === FoundationUnboundedMailbox 测试 ===

@Test
func testFoundationUnboundedMailbox_creation() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-unbounded"
    )
    let mailbox = FoundationUnboundedMailbox(config)

    @Expect(mailbox.getName(), "test-unbounded")
    @Expect(mailbox.isEmpty(), true)
    @Expect(mailbox.size(), 0)
}

@Test
func testFoundationUnboundedMailbox_enqueueDequeue() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-unbounded"
    )
    let mailbox = FoundationUnboundedMailbox(config)

    let env1 = createTestEnvelope(1, "msg1")
    let env2 = createTestEnvelope(2, "msg2")

    @Expect(mailbox.enqueue(env1), true)
    @Expect(mailbox.enqueue(env2), true)
    @Expect(mailbox.size(), 2)
    @Expect(mailbox.isEmpty(), false)
}

@Test
func testFoundationUnboundedMailbox_dequeueReturnsMessage() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-unbounded"
    )
    let mailbox = FoundationUnboundedMailbox(config)

    let env = createTestEnvelope(42, "test-content")
    mailbox.enqueue(env)

    match (mailbox.dequeue()) {
        case Some(e) =>
            match (e.getMessage()) {
                case m: TestMessage =>
                    @Expect(m.getId(), 42)
                    @Expect(m.getContent(), "test-content")
                case _ => @Expect(false, true)
            }
        case None => @Expect(false, true)
    }
}

@Test
func testFoundationUnboundedMailbox_dequeueEmptyReturnsNone() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-unbounded"
    )
    let mailbox = FoundationUnboundedMailbox(config)

    match (mailbox.dequeue()) {
        case Some(_) => @Expect(false, true)
        case None => @Expect(true, true)
    }
}

@Test
func testFoundationUnboundedMailbox_fifoOrder() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-unbounded"
    )
    let mailbox = FoundationUnboundedMailbox(config)

    mailbox.enqueue(createTestEnvelope(1, "first"))
    mailbox.enqueue(createTestEnvelope(2, "second"))
    mailbox.enqueue(createTestEnvelope(3, "third"))

    match (mailbox.dequeue()) {
        case Some(e) =>
            match (e.getMessage()) {
                case m: TestMessage => @Expect(m.getId(), 1)
                case _ => @Expect(false, true)
            }
        case None => @Expect(false, true)
    }

    match (mailbox.dequeue()) {
        case Some(e) =>
            match (e.getMessage()) {
                case m: TestMessage => @Expect(m.getId(), 2)
                case _ => @Expect(false, true)
            }
        case None => @Expect(false, true)
    }
}

@Test
func testFoundationUnboundedMailbox_clear() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-unbounded"
    )
    let mailbox = FoundationUnboundedMailbox(config)

    mailbox.enqueue(createTestEnvelope(1, "msg1"))
    mailbox.enqueue(createTestEnvelope(2, "msg2"))
    @Expect(mailbox.size(), 2)

    mailbox.clear()
    @Expect(mailbox.size(), 0)
    @Expect(mailbox.isEmpty(), true)
}

@Test
func testFoundationUnboundedMailbox_batchOperations() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-unbounded"
    )
    let mailbox = FoundationUnboundedMailbox(config)

    // 入队10条消息
    for (i in 0..10) {
        mailbox.enqueue(createTestEnvelope(i, "msg${i}"))
    }
    @Expect(mailbox.size(), 10)

    // 批量出队5条
    let batch = mailbox.dequeueBatch(5)
    @Expect(Int64(batch.size), 5)
    @Expect(mailbox.size(), 5)
}

@Test
func testFoundationUnboundedMailbox_hasMessages() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-unbounded"
    )
    let mailbox = FoundationUnboundedMailbox(config)

    @Expect(mailbox.hasMessages(), false)

    mailbox.enqueue(createTestEnvelope(1, "msg1"))
    @Expect(mailbox.hasMessages(), true)

    mailbox.dequeue()
    @Expect(mailbox.hasMessages(), false)
}

// === FoundationBoundedMailbox 测试 ===

@Test
func testFoundationBoundedMailbox_creation() {
    let config = MailboxConfig(
        MailboxType.Bounded,
        100,
        Duration.second * 10,
        0,
        "test-bounded"
    )
    let mailbox = FoundationBoundedMailbox(config)

    @Expect(mailbox.getName(), "test-bounded")
    @Expect(mailbox.isEmpty(), true)
    @Expect(mailbox.isFull(), false)
}

@Test
func testFoundationBoundedMailbox_capacityLimit() {
    let config = MailboxConfig(
        MailboxType.Bounded,
        5,
        Duration.second * 10,
        0,
        "test-bounded"
    )
    let mailbox = FoundationBoundedMailbox(config)

    // 入队5条，应该成功
    for (i in 0..5) {
        @Expect(mailbox.enqueue(createTestEnvelope(i, "msg${i}")), true)
    }

    // 第6条应该失败
    @Expect(mailbox.enqueue(createTestEnvelope(99, "overflow")), false)
    @Expect(mailbox.isFull(), true)
}

@Test
func testFoundationBoundedMailbox_remainingCapacity() {
    let config = MailboxConfig(
        MailboxType.Bounded,
        10,
        Duration.second * 10,
        0,
        "test-bounded"
    )
    let mailbox = FoundationBoundedMailbox(config)

    @Expect(mailbox.remainingCapacity(), 10)

    mailbox.enqueue(createTestEnvelope(1, "msg1"))
    @Expect(mailbox.remainingCapacity(), 9)

    mailbox.enqueue(createTestEnvelope(2, "msg2"))
    @Expect(mailbox.remainingCapacity(), 8)
}

@Test
func testFoundationBoundedMailbox_utilization() {
    let config = MailboxConfig(
        MailboxType.Bounded,
        100,
        Duration.second * 10,
        0,
        "test-bounded"
    )
    let mailbox = FoundationBoundedMailbox(config)

    @Expect(mailbox.getUtilization(), 0.0)

    for (i in 0..50) {
        mailbox.enqueue(createTestEnvelope(i, "msg${i}"))
    }
    @Expect(mailbox.getUtilization(), 0.5)
}

@Test
func testFoundationBoundedMailbox_dequeueFreesCapacity() {
    let config = MailboxConfig(
        MailboxType.Bounded,
        5,
        Duration.second * 10,
        0,
        "test-bounded"
    )
    let mailbox = FoundationBoundedMailbox(config)

    // 填满
    for (i in 0..5) {
        mailbox.enqueue(createTestEnvelope(i, "msg${i}"))
    }
    @Expect(mailbox.isFull(), true)

    // 出队一条
    mailbox.dequeue()
    @Expect(mailbox.isFull(), false)
    @Expect(mailbox.remainingCapacity(), 1)
}

// === SPSCMailbox 测试 ===

@Test
func testSPSCMailbox_creation() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-spsc"
    )
    let mailbox = SPSCMailbox(config)

    @Expect(mailbox.getName(), "test-spsc")
    @Expect(mailbox.isEmpty(), true)
}

@Test
func testSPSCMailbox_basicOperations() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-spsc"
    )
    let mailbox = SPSCMailbox(config)

    let env = createTestEnvelope(1, "test")
    @Expect(mailbox.enqueue(env), true)
    @Expect(mailbox.size(), 1)

    match (mailbox.dequeue()) {
        case Some(e) =>
            match (e.getMessage()) {
                case m: TestMessage => @Expect(m.getId(), 1)
                case _ => @Expect(false, true)
            }
        case None => @Expect(false, true)
    }
}

@Test
func testSPSCMailbox_batchEnqueue() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-spsc"
    )
    let mailbox = SPSCMailbox(config)

    let envelopes = ArrayList<Envelope>()
    for (i in 0..5) {
        envelopes.add(createTestEnvelope(i, "batch${i}"))
    }
    let count = mailbox.enqueueBatch(envelopes.toArray())
    @Expect(Int64(count), 5)
    @Expect(mailbox.size(), 5)
}

@Test
func testSPSCMailbox_batchDequeue() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-spsc"
    )
    let mailbox = SPSCMailbox(config)

    // 先入队10条
    for (i in 0..10) {
        mailbox.enqueue(createTestEnvelope(i, "msg${i}"))
    }

    // 批量出队3条
    let batch = mailbox.dequeueBatch(3)
    @Expect(Int64(batch.size), 3)
    @Expect(mailbox.size(), 7)
}

// === MPSCMailbox 测试 ===

@Test
func testMPSCMailbox_creation() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-mpsc"
    )
    let mailbox = MPSCMailbox(config)

    @Expect(mailbox.getName(), "test-mpsc")
    @Expect(mailbox.isEmpty(), true)
}

@Test
func testMPSCMailbox_multipleProducers() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-mpsc"
    )
    let mailbox = MPSCMailbox(config)

    // 模拟多个生产者入队
    mailbox.enqueue(createTestEnvelope(1, "producer1-msg1"))
    mailbox.enqueue(createTestEnvelope(2, "producer2-msg1"))
    mailbox.enqueue(createTestEnvelope(3, "producer1-msg2"))
    mailbox.enqueue(createTestEnvelope(4, "producer3-msg1"))

    @Expect(mailbox.size(), 4)
}

@Test
func testMPSCMailbox_dequeueBatch() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-mpsc"
    )
    let mailbox = MPSCMailbox(config)

    for (i in 0..10) {
        mailbox.enqueue(createTestEnvelope(i, "msg${i}"))
    }

    let batch = mailbox.dequeueBatch(5)
    @Expect(Int64(batch.size), 5)
}

@Test
func testMPSCMailbox_fastEnqueue() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-mpsc"
    )
    let mailbox = MPSCMailbox(config)

    @Expect(mailbox.fastEnqueue(createTestEnvelope(1, "fast1")), true)
    @Expect(mailbox.fastEnqueue(createTestEnvelope(2, "fast2")), true)
    @Expect(mailbox.size(), 2)
}

// === FoundationStashingMailbox 测试 ===

@Test
func testFoundationStashingMailbox_creation() {
    let config = MailboxConfig(
        MailboxType.Stashing,
        100,
        Duration.second * 10,
        50,  // stashCapacity
        "test-stashing"
    )
    let mailbox = FoundationStashingMailbox(config)

    @Expect(mailbox.getName(), "test-stashing")
    @Expect(mailbox.isEmpty(), true)
    @Expect(mailbox.isStashEmpty(), true)
    @Expect(mailbox.stashSize(), 0)
}

@Test
func testFoundationStashingMailbox_basicEnqueueDequeue() {
    let config = MailboxConfig(
        MailboxType.Stashing,
        100,
        Duration.second * 10,
        50,
        "test-stashing"
    )
    let mailbox = FoundationStashingMailbox(config)

    let env = createTestEnvelope(1, "test")
    @Expect(mailbox.enqueue(env), true)
    @Expect(mailbox.size(), 1)
    @Expect(mailbox.isEmpty(), false)

    match (mailbox.dequeue()) {
        case Some(e) =>
            match (e.getMessage()) {
                case m: TestMessage => @Expect(m.getId(), 1)
                case _ => @Expect(false, true)
            }
        case None => @Expect(false, true)
    }

    @Expect(mailbox.size(), 0)
    @Expect(mailbox.isEmpty(), true)
}

@Test
func testFoundationStashingMailbox_stash() {
    let config = MailboxConfig(
        MailboxType.Stashing,
        100,
        Duration.second * 10,
        50,
        "test-stashing"
    )
    let mailbox = FoundationStashingMailbox(config)

    let env1 = createTestEnvelope(1, "normal")
    let env2 = createTestEnvelope(2, "stashed")

    // 正常入队
    mailbox.enqueue(env1)
    @Expect(mailbox.size(), 1)

    // 暂存消息
    @Expect(mailbox.stash(env2), true)
    @Expect(mailbox.stashSize(), 1)
    @Expect(mailbox.isStashEmpty(), false)
    @Expect(mailbox.size(), 1)  // 正常队列大小不变
}

@Test
func testFoundationStashingMailbox_stashCapacityLimit() {
    let config = MailboxConfig(
        MailboxType.Stashing,
        100,
        Duration.second * 10,
        3,  // 限制暂存容量为3
        "test-stashing"
    )
    let mailbox = FoundationStashingMailbox(config)

    // 暂存3条，应该成功
    @Expect(mailbox.stash(createTestEnvelope(1, "s1")), true)
    @Expect(mailbox.stash(createTestEnvelope(2, "s2")), true)
    @Expect(mailbox.stash(createTestEnvelope(3, "s3")), true)
    @Expect(mailbox.stashSize(), 3)

    // 第4条应该失败
    @Expect(mailbox.stash(createTestEnvelope(4, "s4")), false)
    @Expect(mailbox.stashSize(), 3)
}

@Test
func testFoundationStashingMailbox_unstashAll() {
    let config = MailboxConfig(
        MailboxType.Stashing,
        100,
        Duration.second * 10,
        50,
        "test-stashing"
    )
    let mailbox = FoundationStashingMailbox(config)

    // 添加一些正常消息
    mailbox.enqueue(createTestEnvelope(1, "normal1"))

    // 暂存一些消息
    mailbox.stash(createTestEnvelope(10, "stashed1"))
    mailbox.stash(createTestEnvelope(11, "stashed2"))
    mailbox.stash(createTestEnvelope(12, "stashed3"))

    @Expect(mailbox.stashSize(), 3)
    @Expect(mailbox.size(), 1)

    // 恢复所有暂存消息
    let count = mailbox.unstashAll()
    @Expect(count, 3)
    @Expect(mailbox.stashSize(), 0)
    @Expect(mailbox.isStashEmpty(), true)
    @Expect(mailbox.size(), 4)  // 1 + 3
}

@Test
func testFoundationStashingMailbox_unstashPartial() {
    let config = MailboxConfig(
        MailboxType.Stashing,
        100,
        Duration.second * 10,
        50,
        "test-stashing"
    )
    let mailbox = FoundationStashingMailbox(config)

    // 暂存5条消息
    mailbox.stash(createTestEnvelope(1, "s1"))
    mailbox.stash(createTestEnvelope(2, "s2"))
    mailbox.stash(createTestEnvelope(3, "s3"))
    mailbox.stash(createTestEnvelope(4, "s4"))
    mailbox.stash(createTestEnvelope(5, "s5"))

    @Expect(mailbox.stashSize(), 5)

    // 只恢复2条
    let count = mailbox.unstash(2)
    @Expect(count, 2)
    @Expect(mailbox.stashSize(), 3)
    @Expect(mailbox.size(), 2)
}

@Test
func testFoundationStashingMailbox_unstashStopsWhenQueueFull() {
    let config = MailboxConfig(
        MailboxType.Stashing,
        5,  // 限制正常队列容量为5
        Duration.second * 10,
        50,
        "test-stashing"
    )
    let mailbox = FoundationStashingMailbox(config)

    // 先填满正常队列
    for (i in 0..5) {
        mailbox.enqueue(createTestEnvelope(i, "normal${i}"))
    }

    // 暂存一些消息
    mailbox.stash(createTestEnvelope(100, "s1"))
    mailbox.stash(createTestEnvelope(101, "s2"))

    // 恢复时应该因为队列满而停止
    let count = mailbox.unstashAll()
    @Expect(count, 0)  // 没有恢复任何消息，因为队列已满
    @Expect(mailbox.stashSize(), 2)
}

@Test
func testFoundationStashingMailbox_clearStash() {
    let config = MailboxConfig(
        MailboxType.Stashing,
        100,
        Duration.second * 10,
        50,
        "test-stashing"
    )
    let mailbox = FoundationStashingMailbox(config)

    mailbox.stash(createTestEnvelope(1, "s1"))
    mailbox.stash(createTestEnvelope(2, "s2"))
    @Expect(mailbox.stashSize(), 2)

    mailbox.clearStash()
    @Expect(mailbox.stashSize(), 0)
    @Expect(mailbox.isStashEmpty(), true)
}

@Test
func testFoundationStashingMailbox_clearClearsBoth() {
    let config = MailboxConfig(
        MailboxType.Stashing,
        100,
        Duration.second * 10,
        50,
        "test-stashing"
    )
    let mailbox = FoundationStashingMailbox(config)

    mailbox.enqueue(createTestEnvelope(1, "normal"))
    mailbox.stash(createTestEnvelope(2, "stashed"))

    @Expect(mailbox.size(), 1)
    @Expect(mailbox.stashSize(), 1)

    mailbox.clear()

    @Expect(mailbox.size(), 0)
    @Expect(mailbox.stashSize(), 0)
}

@Test
func testFoundationStashingMailbox_fifoOrderWithStash() {
    let config = MailboxConfig(
        MailboxType.Stashing,
        100,
        Duration.second * 10,
        50,
        "test-stashing"
    )
    let mailbox = FoundationStashingMailbox(config)

    // 入队顺序: 1, 2, 3
    mailbox.enqueue(createTestEnvelope(1, "msg1"))
    mailbox.enqueue(createTestEnvelope(2, "msg2"))
    mailbox.enqueue(createTestEnvelope(3, "msg3"))

    // 暂存: 10, 11
    mailbox.stash(createTestEnvelope(10, "stash1"))
    mailbox.stash(createTestEnvelope(11, "stash2"))

    // 出队应该先出正常的，再出暂存的
    match (mailbox.dequeue()) {
        case Some(e) =>
            match (e.getMessage()) {
                case m: TestMessage => @Expect(m.getId(), 1)
                case _ => @Expect(false, true)
            }
        case None => @Expect(false, true)
    }

    // 恢复暂存
    mailbox.unstashAll()

    // 继续出队
    match (mailbox.dequeue()) {
        case Some(e) =>
            match (e.getMessage()) {
                case m: TestMessage => @Expect(m.getId(), 2)
                case _ => @Expect(false, true)
            }
        case None => @Expect(false, true)
    }

    match (mailbox.dequeue()) {
        case Some(e) =>
            match (e.getMessage()) {
                case m: TestMessage => @Expect(m.getId(), 3)
                case _ => @Expect(false, true)
            }
        case None => @Expect(false, true)
    }

    // 暂存的消息
    match (mailbox.dequeue()) {
        case Some(e) =>
            match (e.getMessage()) {
                case m: TestMessage => @Expect(m.getId(), 10)
                case _ => @Expect(false, true)
            }
        case None => @Expect(false, true)
    }

    match (mailbox.dequeue()) {
        case Some(e) =>
            match (e.getMessage()) {
                case m: TestMessage => @Expect(m.getId(), 11)
                case _ => @Expect(false, true)
            }
        case None => @Expect(false, true)
    }
}

// === 边界情况测试 ===

@Test
func testMailbox_multipleEnqueueDequeue() {
    let config = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test-stress"
    )
    let mailbox = FoundationUnboundedMailbox(config)

    // 100次入队
    for (i in 0..100) {
        mailbox.enqueue(createTestEnvelope(i, "msg${i}"))
    }
    @Expect(mailbox.size(), 100)

    // 50次出队
    for (i in 0..50) {
        match (mailbox.dequeue()) {
            case Some(_) => ()
            case None => @Expect(false, true)
        }
    }
    @Expect(mailbox.size(), 50)
}

@Test
func testFoundationStashingMailbox_repeatedStashUnstash() {
    let config = MailboxConfig(
        MailboxType.Stashing,
        100,
        Duration.second * 10,
        50,
        "test-repeated"
    )
    let mailbox = FoundationStashingMailbox(config)

    // 多次暂存和恢复循环
    for (round in 0..5) {
        // 填满暂存
        for (i in 0..10) {
            mailbox.stash(createTestEnvelope(round * 100 + i, "round${round}-${i}"))
        }

        // 恢复一部分
        mailbox.unstash(5)
        @Expect(mailbox.stashSize(), 5)
        @Expect(mailbox.size(), 5)
    }
}

@Test
func testFoundationBoundedMailbox_exactCapacity() {
    let config = MailboxConfig(
        MailboxType.Bounded,
        3,
        Duration.second * 10,
        0,
        "test-exact"
    )
    let mailbox = FoundationBoundedMailbox(config)

    @Expect(mailbox.enqueue(createTestEnvelope(1, "1")), true)
    @Expect(mailbox.enqueue(createTestEnvelope(2, "2")), true)
    @Expect(mailbox.enqueue(createTestEnvelope(3, "3")), true)
    @Expect(mailbox.enqueue(createTestEnvelope(4, "4")), false)  // 满

    // 出队后应该可以再入队
    mailbox.dequeue()
    @Expect(mailbox.enqueue(createTestEnvelope(5, "5")), true)
}

@Test
func testMailbox_interfaces() {
    // 验证所有邮箱都实现了Mailbox接口
    let unboundedConfig = MailboxConfig(
        MailboxType.Unbounded,
        1024,
        Duration.second * 10,
        0,
        "test"
    )
    let boundedConfig = MailboxConfig(
        MailboxType.Bounded,
        100,
        Duration.second * 10,
        0,
        "test"
    )
    let stashingConfig = MailboxConfig(
        MailboxType.Stashing,
        100,
        Duration.second * 10,
        50,
        "test"
    )

    let unbounded: Mailbox = FoundationUnboundedMailbox(unboundedConfig)
    let bounded: Mailbox = FoundationBoundedMailbox(boundedConfig)
    let stashing: Mailbox = FoundationStashingMailbox(stashingConfig)

    // 基本接口测试
    unbounded.enqueue(createTestEnvelope(1, "test"))
    bounded.enqueue(createTestEnvelope(1, "test"))
    stashing.enqueue(createTestEnvelope(1, "test"))

    @Expect(unbounded.size(), 1)
    @Expect(bounded.size(), 1)
    @Expect(stashing.size(), 1)
}
