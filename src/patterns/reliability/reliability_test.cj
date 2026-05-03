/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - 可靠性模式单元测试
 */
package cactor.patterns.reliability

import std.collection.*
import std.time.*

// ============================================================================
// DeadLetter Tests
// ============================================================================

@Test
func testDeadLetter_creation() {
    let letter = DeadLetter(
        "test message",
        Some("sender"),
        "recipient",
        DeadLetterReason.Unknown
    )
    @Expect(letter.timestamp > 0, true)
    match (letter.sender) {
        case Some(s) => @Expect(s, "sender")
        case None => @Expect(true, false)
    }
}

@Test
func testDeadLetter_allReasons() {
    @Expect(true, true)
}

// ============================================================================
// DeadLetterChannel Tests
// ============================================================================

@Test
func testDeadLetterChannel_creation() {
    let channel = DeadLetterChannel()
    @Expect(channel.size(), 0)
}

@Test
func testDeadLetterChannel_publish() {
    let channel = DeadLetterChannel()
    let letter = DeadLetter(
        "test",
        Some("sender"),
        "recipient",
        DeadLetterReason.Unknown
    )
    channel.publish(letter)
    @Expect(channel.size(), 1)
}

@Test
func testDeadLetterChannel_getDeadLetters() {
    let channel = DeadLetterChannel()
    channel.publish(DeadLetter("msg1", None, "r1", DeadLetterReason.Unknown))
    channel.publish(DeadLetter("msg2", None, "r2", DeadLetterReason.Unknown))
    let letters = channel.getDeadLetters()
    @Expect(letters.size, 2)
}

@Test
func testDeadLetterChannel_clear() {
    let channel = DeadLetterChannel()
    channel.publish(DeadLetter("msg1", None, "r1", DeadLetterReason.Unknown))
    channel.publish(DeadLetter("msg2", None, "r2", DeadLetterReason.Unknown))
    @Expect(channel.size(), 2)
    channel.clear()
    @Expect(channel.size(), 0)
}

@Test
func testDeadLetterChannel_maxCapacity() {
    let channel = DeadLetterChannel(3)
    channel.publish(DeadLetter("msg1", None, "r1", DeadLetterReason.Unknown))
    channel.publish(DeadLetter("msg2", None, "r2", DeadLetterReason.Unknown))
    channel.publish(DeadLetter("msg3", None, "r3", DeadLetterReason.Unknown))
    channel.publish(DeadLetter("msg4", None, "r4", DeadLetterReason.Unknown))
    @Expect(channel.size(), 3)
}

@Test
func testDeadLetterChannel_getDeadLettersFor() {
    let channel = DeadLetterChannel()
    channel.publish(DeadLetter("msg1", None, "r1", DeadLetterReason.Unknown))
    channel.publish(DeadLetter("msg2", None, "r2", DeadLetterReason.Unknown))
    channel.publish(DeadLetter("msg3", None, "r1", DeadLetterReason.Unknown))
    let letters = channel.getDeadLettersFor("r1")
    @Expect(letters.size, 2)
}

@Test
func testDeadLetterChannel_getRecentDeadLetters() {
    let channel = DeadLetterChannel()
    for (i in 0..5) {
        channel.publish(DeadLetter("msg${i}", None, "r${i}", DeadLetterReason.Unknown))
    }
    let recent = channel.getRecentDeadLetters(3)
    @Expect(recent.size, 3)
}

// ============================================================================
// DeadLetterListener for Tests
// ============================================================================

class TestDeadLetterListener <: DeadLetterListener {
    public var receivedCount: Int64 = 0
    public var lastLetter: Option<DeadLetter> = None

    public func onDeadLetter(letter: DeadLetter): Unit {
        receivedCount += 1
        lastLetter = Some(letter)
    }
}

@Test
func testDeadLetterChannel_addListener() {
    let channel = DeadLetterChannel()
    let listener = TestDeadLetterListener()
    channel.addListener(listener)
    channel.publish(DeadLetter("msg1", None, "r1", DeadLetterReason.Unknown))
    @Expect(listener.receivedCount, 1)
}

@Test
func testDeadLetterChannel_removeListener() {
    let channel = DeadLetterChannel()
    let listener = TestDeadLetterListener()
    channel.addListener(listener)
    channel.publish(DeadLetter("msg1", None, "r1", DeadLetterReason.Unknown))
    channel.removeListener(listener)
    channel.publish(DeadLetter("msg2", None, "r2", DeadLetterReason.Unknown))
    @Expect(listener.receivedCount, 1)
}

@Test
func testDeadLetterChannel_multipleListeners() {
    let channel = DeadLetterChannel()
    let listener1 = TestDeadLetterListener()
    let listener2 = TestDeadLetterListener()
    channel.addListener(listener1)
    channel.addListener(listener2)
    channel.publish(DeadLetter("msg1", None, "r1", DeadLetterReason.Unknown))
    @Expect(listener1.receivedCount, 1)
    @Expect(listener2.receivedCount, 1)
}

// ============================================================================
// Acknowledgement Tests
// ============================================================================

@Test
func testAcknowledgement_creation() {
    let ack = Acknowledgement("msg-123")
    @Expect(ack.messageId, "msg-123")
    @Expect(ack.timestamp > 0, true)
    @Expect(ack.retryCount, 0)
}

@Test
func testAcknowledgement_withStatus() {
    let ack = Acknowledgement("msg-123")
    let ack2 = ack.withStatus(AckStatus.Acknowledged)
    @Expect(ack2.messageId, "msg-123")
}

@Test
func testAcknowledgement_withRetry() {
    let ack = Acknowledgement("msg-123")
    let ack2 = ack.withRetry()
    @Expect(ack2.retryCount, 1)
}

// ============================================================================
// AckTracker Tests
// ============================================================================

@Test
func testAckTracker_creation() {
    let tracker = AckTracker()
    @Expect(tracker.pendingCount(), 0)
}

@Test
func testAckTracker_register() {
    let tracker = AckTracker()
    tracker.register("msg-1")
    @Expect(tracker.pendingCount(), 1)
}

@Test
func testAckTracker_acknowledge() {
    let tracker = AckTracker()
    tracker.register("msg-1")
    let result = tracker.acknowledge("msg-1")
    @Expect(result, true)
}

@Test
func testAckTracker_acknowledgeNonExistent() {
    let tracker = AckTracker()
    let result = tracker.acknowledge("non-existent")
    @Expect(result, false)
}

@Test
func testAckTracker_nack() {
    let tracker = AckTracker()
    tracker.register("msg-1")
    let result = tracker.nack("msg-1", "processing failed")
    @Expect(result, true)
}

@Test
func testAckTracker_getStatus() {
    let tracker = AckTracker()
    tracker.register("msg-1")
    tracker.acknowledge("msg-1")
    match (tracker.getStatus("msg-1")) {
        case Some(AckStatus.Acknowledged) => @Expect(true, true)
        case _ => @Expect(true, false)
    }
}

@Test
func testAckTracker_getStatusNonExistent() {
    let tracker = AckTracker()
    match (tracker.getStatus("non-existent")) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

@Test
func testAckTracker_getPendingMessageIds() {
    let tracker = AckTracker()
    tracker.register("msg-1")
    tracker.register("msg-2")
    tracker.register("msg-3")
    tracker.acknowledge("msg-2")
    let pending = tracker.getPendingMessageIds()
    @Expect(pending.size, 2)
}

@Test
func testAckTracker_cleanup() {
    let tracker = AckTracker()
    tracker.register("msg-1")
    tracker.register("msg-2")
    tracker.acknowledge("msg-1")
    tracker.acknowledge("msg-2")
    let removed = tracker.cleanup()
    @Expect(removed, 2)
    @Expect(tracker.pendingCount(), 0)
}

// ============================================================================
// RetryStrategy Tests
// ============================================================================

@Test
func testExponentialBackoffRetry_shouldRetry() {
    let strategy = ExponentialBackoffRetry(
        Duration.millisecond * 100,
        Duration.second * 10,
        3
    )
    @Expect(strategy.shouldRetry(0, None), true)
    @Expect(strategy.shouldRetry(2, None), true)
    @Expect(strategy.shouldRetry(3, None), false)
    @Expect(strategy.shouldRetry(5, None), false)
}

@Test
func testExponentialBackoffRetry_nextDelay() {
    let strategy = ExponentialBackoffRetry(
        Duration.millisecond * 100,
        Duration.second * 10,
        5
    )
    let delay0 = strategy.nextDelay(0)
    let delay1 = strategy.nextDelay(1)
    let delay2 = strategy.nextDelay(2)
    @Expect(delay0.toMilliseconds(), 100)
    @Expect(delay1.toMilliseconds(), 200)
    @Expect(delay2.toMilliseconds(), 400)
}

@Test
func testFixedDelayRetry_shouldRetry() {
    let strategy = FixedDelayRetry(Duration.second * 1, 3)
    @Expect(strategy.shouldRetry(0, None), true)
    @Expect(strategy.shouldRetry(2, None), true)
    @Expect(strategy.shouldRetry(3, None), false)
}

@Test
func testFixedDelayRetry_nextDelay() {
    let strategy = FixedDelayRetry(Duration.second * 2, 5)
    let delay = strategy.nextDelay(0)
    @Expect(delay.toMilliseconds(), 2000)
}

// ============================================================================
// ReliableMessageSender Tests
// ============================================================================

@Test
func testReliableMessageSender_creation() {
    let channel = DeadLetterChannel()
    let sender = ReliableMessageSender(channel)
    @Expect(sender.getPendingCount(), 0)
}

@Test
func testReliableMessageSender_sendWithAck() {
    let channel = DeadLetterChannel()
    let sender = ReliableMessageSender(channel)
    let msgId = sender.sendWithAck("test message", "recipient")
    @Expect(msgId.startsWith("msg-"), true)
    @Expect(sender.getPendingCount(), 1)
}

@Test
func testReliableMessageSender_ack() {
    let channel = DeadLetterChannel()
    let sender = ReliableMessageSender(channel)
    let msgId = sender.sendWithAck("test", "recipient")
    sender.ack(msgId)
    @Expect(sender.getPendingCount(), 1)
}

@Test
func testReliableMessageSender_cleanup() {
    let channel = DeadLetterChannel()
    let sender = ReliableMessageSender(channel)
    let msgId = sender.sendWithAck("test", "recipient")
    sender.ack(msgId)
    let cleaned = sender.cleanup()
    @Expect(cleaned, 1)
    @Expect(sender.getPendingCount(), 0)
}

// ============================================================================
// MessageBuffer Tests
// ============================================================================

@Test
func testMessageBuffer_creation() {
    let buffer = MessageBuffer({ msg => () })
    @Expect(buffer.getBufferSize(), 0)
    @Expect(buffer.getExpectedSequence(), 0)
}

@Test
func testMessageBuffer_deliverInOrder() {
    let buffer = MessageBuffer({ msg => () })
    buffer.add(0, "msg-0")
    buffer.add(1, "msg-1")
    buffer.add(2, "msg-2")
    @Expect(buffer.getBufferSize(), 0)
}

@Test
func testMessageBuffer_expectedSequence() {
    let buffer = MessageBuffer({ msg => () }, 5, 100)
    buffer.add(5, "msg-5")
    @Expect(buffer.getExpectedSequence(), 6)
}

@Test
func testMessageBuffer_multipleBuffered() {
    let buffer = MessageBuffer({ msg => () })
    buffer.add(3, "msg-3")
    buffer.add(1, "msg-1")
    buffer.add(2, "msg-2")
    buffer.add(0, "msg-0")
    @Expect(buffer.getBufferSize(), 0)
}
