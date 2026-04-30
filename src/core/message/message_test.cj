/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Message 单元测试
 */
package cactor.core.message

import std.collection.*
import std.time.*

@Test
func testMessageResult_values() {
    @Expect(MessageResult.Handled.toString().size > 0, true)
    @Expect(MessageResult.Unhandled.toString().size > 0, true)
    @Expect(MessageResult.Stop.toString().size > 0, true)
    @Expect(MessageResult.Restart.toString().size > 0, true)
    @Expect(MessageResult.Escalate.toString().size > 0, true)
}

@Test
func testStopMessage_defaultReason() {
    let msg = StopMessage()

    @Expect(msg.messageType(), "StopMessage")
    @Expect(msg.getReason(), "Normal stop")
    @Expect(msg.priority() > 0, true)
}

@Test
func testStopMessage_customReason() {
    let msg = StopMessage("Custom stop reason")

    @Expect(msg.messageType(), "StopMessage")
    @Expect(msg.getReason(), "Custom stop reason")
}

@Test
func testRestartMessage() {
    let exception = Exception("Test exception")
    let msg = RestartMessage(exception)

    @Expect(msg.messageType(), "RestartMessage")
    @Expect(msg.getCause() !== None, true)
}

@Test
func testSuspendMessage() {
    let msg = SuspendMessage()

    @Expect(msg.messageType(), "SuspendMessage")
    @Expect(msg.priority() > 0, true)
}

@Test
func testResumeMessage() {
    let msg = ResumeMessage()

    @Expect(msg.messageType(), "ResumeMessage")
    @Expect(msg.priority() > 0, true)
}

@Test
func testTerminatedMessage() {
    let msg = TerminatedMessage("/test/actor", "Normal termination")

    @Expect(msg.messageType(), "TerminatedMessage")
    @Expect(msg.getActor(), "/test/actor")
    @Expect(msg.getReason(), "Normal termination")
}

@Test
func testStringMessage() {
    let msg = StringMessage("Hello, Actor!")

    @Expect(msg.messageType(), "StringMessage")
    @Expect(msg.getContent(), "Hello, Actor!")
}

@Test
func testPingMessage() {
    let msg = PingMessage(42)

    @Expect(msg.messageType(), "PingMessage")
    @Expect(msg.getId(), 42)
    @Expect(msg.timestamp() > 0, true)
}

@Test
func testPongMessage() {
    let msg = PongMessage(42)

    @Expect(msg.messageType(), "PongMessage")
    @Expect(msg.getOriginalId(), 42)
    @Expect(msg.timestamp() > 0, true)
}

@Test
func testEnvelope_creation() {
    let innerMsg = StringMessage("Test message")
    let envelope = Envelope(innerMsg, Some("/sender"))

    @Expect(envelope.getMessage() === innerMsg, true)
    @Expect(envelope.getSender() === Some("/sender"), true)
    @Expect(envelope.getTimestamp() > 0, true)
}

@Test
func testEnvelope_noSender() {
    let innerMsg = StringMessage("Test message")
    let envelope = Envelope(innerMsg, None)

    @Expect(envelope.getMessage() === innerMsg, true)
    @Expect(envelope.getSender() === None, true)
}

@Test
func testDeadLetter() {
    let innerMsg = StringMessage("Original message")
    let deadLetter = DeadLetter(innerMsg, "/sender", "/receiver")

    @Expect(deadLetter.messageType(), "DeadLetter")
    @Expect(deadLetter.getSender(), "/sender")
    @Expect(deadLetter.getRecipient(), "/receiver")
    @Expect(deadLetter.getMessage() === innerMsg, true)
    @Expect(deadLetter.priority() > 0, true)
}

@Test
func testMessage_defaultPriority() {
    let msg = StringMessage("Test")
    @Expect(msg.priority(), 0)
}

@Test
func testMessage_defaultMessageId() {
    let msg = StringMessage("Test")
    @Expect(msg.messageId(), "")
}

@Test
func testSystemMessage_highPriority() {
    let msg = StopMessage()
    @Expect(msg.priority() >= 1000, true)
}

@Test
func testUserMessage_normalPriority() {
    let msg = StringMessage("Test")
    @Expect(msg.priority(), 0)
}

@Test
func testEnvelope_ordering() {
    let msg1 = StringMessage("First")
    let msg2 = StringMessage("Second")

    let envelope1 = Envelope(msg1, Some("/sender1"))
    let envelope2 = Envelope(msg2, Some("/sender2"))

    // 后创建的消息时间戳应该更大
    @Expect(envelope2.getTimestamp() >= envelope1.getTimestamp(), true)
}

@Test
func testPingPongMessage_timestamps() {
    let ping = PingMessage(1)
    let pong = PongMessage(1)

    // 两者应该有不同的消息类型
    @Expect(ping.messageType() !== pong.messageType(), true)
    @Expect(ping.getId() === pong.getOriginalId(), true)
}

/*
 * 测试辅助类
 */

@Test
func testCustomMessage_implementation() {
    let msg = TestCustomMessage("test data", 42)

    @Expect(msg.messageType(), "TestCustomMessage")
    @Expect(msg.getData(), "test data")
    @Expect(msg.getValue(), 42)
    @Expect(msg.priority(), 5)
}

@Test
func testCustomMessage_priority() {
    let msg = TestCustomMessage("test", 0)
    @Expect(msg.priority(), 5)
}

@Test
func testCustomMessage_messageId() {
    let msg = TestCustomMessage("test", 0)
    @Expect(msg.messageId(), "custom-123")
}

class TestCustomMessage <: Message {
    private let data: String
    private let value: Int64

    public init(data: String, value: Int64) {
        this.data = data
        this.value = value
    }

    public func messageType(): String {
        "TestCustomMessage"
    }

    public func priority(): Int32 {
        5
    }

    public func messageId(): String {
        "custom-123"
    }

    public func getData(): String {
        data
    }

    public func getValue(): Int64 {
        value
    }
}
