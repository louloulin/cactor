/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Typed Pattern 单元测试
 */
package cactor.patterns.typed

import std.collection.*
import std.time.*
import cactor.core.actor.{Actor, ActorRef, ActorPath, Props, ActorContext, SimpleActorFactory}
import cactor.core.message.{Message, MessageResult}
import cactor.core.system.{ActorSystem}

/**
 * TestCommand - 测试命令
 */
class TestCommand <: Message {
    public let value: String

    public init(value: String) {
        this.value = value
    }

    public func messageType(): String {
        "TestCommand"
    }
}

/**
 * TestResponse - 测试响应
 */
class TestResponse <: Message {
    public let value: String

    public init(value: String) {
        this.value = value
    }

    public func messageType(): String {
        "TestResponse"
    }
}

/**
 * TestHandler - 测试行为处理器
 */
class TestHandler <: ActorBehaviorHandler {
    private var state: String = "initial"
    private let messages: ArrayList<Message>

    public init() {
        this.messages = ArrayList<Message>()
    }

    public func handleMessage(message: Message): Unit {
        messages.add(message)
        state = "handled"
    }

    public func currentState(): String {
        state
    }

    public func getMessages(): Array<Message> {
        messages.toArray()
    }
}

// === TypedEnvelope Tests ===

@Test
func testTypedEnvelope_creation() {
    let msg = TestCommand("test")
    let envelope = TypedEnvelope(msg, "TestProtocol")

    @Expect(envelope.messageType(), "TypedEnvelope[TestProtocol]")
    @Expect(envelope.getProtocolType(), "TestProtocol")
    @Expect(envelope.getMessage().messageType(), "TestCommand")
}

// === TypedActorRefImpl Tests ===

@Test
func testTypedActorRefImpl_tell() {
    let mockRef = TestMockActorRef("test-actor")
    let typedRef = TypedActorRefImpl<TestCommand>(mockRef, "TestProtocol")

    let cmd = TestCommand("hello")
    typedRef.tell(cmd)

    let messages = mockRef.getSentMessages()
    @Expect(messages.size, 1)
}

@Test
func testTypedActorRefImpl_path() {
    let mockRef = TestMockActorRef("test-actor")
    let typedRef = TypedActorRefImpl<TestCommand>(mockRef, "TestProtocol")

    let path = typedRef.path()
    @Expect(path.toString().contains("test-actor"), true)
}

// === ActorBehaviorHandler Tests ===

@Test
func testTestHandler_initialState() {
    let handler = TestHandler()
    @Expect(handler.currentState(), "initial")
}

@Test
func testTestHandler_handleMessage() {
    let handler = TestHandler()
    let msg = TestCommand("test")
    handler.handleMessage(msg)
    @Expect(handler.currentState(), "handled")
}

// === TypedAsk Tests ===

@Test
func testAskPattern_creation() {
    let mockRef = TestMockActorRef("ask-target")
    let pattern = AskPattern<TestCommand, TestResponse>(mockRef, Duration.second * 5)

    match (pattern) {
        case Some(_) => @Expect(true, true)
        case None => @Expect(true, false)
    }
}

@Test
func testAskFuture_creation() {
    let mockRef = TestMockActorRef("ask-target")
    let future = AskFuture<TestResponse>(mockRef, TestCommand("test"), Duration.second * 5)

    @Expect(future.isDone(), false)
}

@Test
func testAskResult_success() {
    let result = AskResult<String>("success")
    @Expect(result.isSuccess(), true)
    @Expect(result.get(), "success")
}

@Test
func testAskResult_error() {
    let result = AskResult<String>("error occurred")
    @Expect(result.isSuccess(), false)
}

@Test
func testAskResult_map() {
    let result = AskResult<Int64>(42)
    let mapped = result.map({ v => v.toString() })
    @Expect(mapped.isSuccess(), true)
    @Expect(mapped.get(), "42")
}

@Test
func testAskResult_getOrDefault() {
    let result = AskResult<String>("error")
    @Expect(result.getOrDefault("default"), "default")
}

// === AskTimeoutException Tests ===

@Test
func testAskTimeoutException_message() {
    let exception = AskTimeoutException(Duration.second * 3)
    let msg = exception.getMessage()
    @Expect(msg.contains("3"), true)
}

// === Test Mock ActorRef ===

class TestMockActorRef <: ActorRef {
    private let mockPath: ActorPath
    private let sentMessages: ArrayList<Message>

    public init(name: String) {
        this.mockPath = ActorPath("test", "/${name}")
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
            case mock: TestMockActorRef => true
            case _ => false
        }
    }

    public func hashCode(): Int32 {
        0
    }

    public func getSentMessages(): ArrayList<Message> {
        sentMessages
    }
}