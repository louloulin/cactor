/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Ask模式单元测试
 */
package cactor.patterns.ask

import std.collection.*
import std.time.*
import cactor.core.actor.{ActorRef, ActorPath}
import cactor.core.message.{Message, Envelope}

/*
 * Test message for Ask tests
 */
class TestRequestMessage <: Message {
    private let content: String

    public init(content: String) {
        this.content = content
    }

    public func messageType(): String { "TestRequestMessage" }
    public func getContent(): String { content }
}

class TestResponseMessage <: Message {
    private let reply: String

    public init(reply: String) {
        this.reply = reply
    }

    public func messageType(): String { "TestResponseMessage" }
    public func getReply(): String { reply }
}

// === AskMessage Tests ===

@Test
func testAskMessage_creation() {
    let ref = DummyActorRef("test-reply")
    let request = TestRequestMessage("hello")
    let askMsg = AskMessage("req-123", request, ref)

    @Expect(askMsg.getRequestId(), "req-123")
    @Expect(askMsg.getOriginalMessage().messageType(), "TestRequestMessage")
    @Expect(askMsg.getReplyTo().equals(ref), true)
}

@Test
func testAskMessage_messageType() {
    let ref = DummyActorRef("test")
    let request = TestRequestMessage("test")
    let askMsg = AskMessage("id", request, ref)
    @Expect(askMsg.messageType(), "AskMessage")
}

// === AskResponse Tests ===

@Test
func testAskResponse_success() {
    let response = TestResponseMessage("world")
    let askResp = AskResponse("req-456", response, true)

    @Expect(askResp.getRequestId(), "req-456")
    @Expect(askResp.isSuccess(), true)
    @Expect(askResp.getResponse().messageType(), "TestResponseMessage")
}

@Test
func testAskResponse_failure() {
    let response = TestResponseMessage("error")
    let askResp = AskResponse("req-789", response, false)

    @Expect(askResp.getRequestId(), "req-789")
    @Expect(askResp.isSuccess(), false)
}

// === AskTimeoutException Tests ===

@Test
func testAskTimeoutException_creation() {
    let timeout = Duration.second * 5
    let ex = AskTimeoutException("timeout-123", timeout)

    @Expect(ex.getRequestId(), "timeout-123")
    @Expect(ex.getTimeout() == timeout, true)
}

// === AskFuture Tests ===

@Test
func testAskFuture_initialization() {
    let future = AskFuture<Message>("test-init", Duration.second * 10)
    @Expect(future.isCompleted(), false)
    @Expect(future.isTimedOut(), false)
}

@Test
func testAskFuture_complete() {
    let future = AskFuture<Message>("test-complete", Duration.second * 10)
    let response = TestResponseMessage("completed")

    future.complete(response)
    @Expect(future.isCompleted(), true)
}

@Test
func testAskFuture_completeWithError() {
    let future = AskFuture<Message>("test-error", Duration.second * 10)
    let error = Exception("test error")

    future.completeWithError(error)
    @Expect(future.isCompleted(), true)
}

@Test
func testAskFuture_getResult() {
    let future = AskFuture<Message>("test-get", Duration.second * 10)
    let response = TestResponseMessage("success")

    future.complete(response)

    let result = future.get()
    @Expect(result.isSuccess(), true)
    match (result) {
        case Result.Success(msg) =>
            @Expect(msg.messageType(), "TestResponseMessage")
        case _ => @Expect(false, true)
    }
}

@Test
func testAskFuture_getResultError() {
    let future = AskFuture<Message>("test-result-error", Duration.second * 10)
    let error = Exception("test failure")

    future.completeWithError(error)

    let result = future.get()
    @Expect(result.isFailure(), true)
}

// === DummyActorRef Tests ===

@Test
func testDummyActorRef_creation() {
    let ref = DummyActorRef("actor-1")
    @Expect(ref.path.toString().size > 0, true)
}

@Test
func testDummyActorRef_equality() {
    let ref1 = DummyActorRef("same-id")
    let ref2 = DummyActorRef("same-id")
    let ref3 = DummyActorRef("different-id")

    @Expect(ref1.equals(ref2), true)
    @Expect(ref1.equals(ref3), false)
}

@Test
func testDummyActorRef_hashCode() {
    let ref1 = DummyActorRef("hash-test")
    let ref2 = DummyActorRef("hash-test")

    @Expect(ref1.hashCode() == ref2.hashCode(), true)
}

@Test
func testDummyActorRef_toString() {
    let ref = DummyActorRef("tostring-test")
    let str = ref.toString()
    @Expect(str.size > 0, true)
}

@Test
func testDummyActorRef_path() {
    let ref = DummyActorRef("path-test")
    let path = ref.path
    @Expect(path.toString().size > 0, true)
}

// === AskPatternManager Tests ===

@Test
func testAskPatternManager_initialization() {
    let manager = AskPatternManager(Duration.second * 30)
    @Expect(manager.getPendingRequestCount(), 0)
    @Expect(manager.getDefaultTimeout() == Duration.second * 30, true)
}

@Test
func testAskPatternManager_getPendingRequestCount() {
    let manager = AskPatternManager(Duration.second * 60)
    manager.start()
    manager.stop()
    @Expect(manager.getPendingRequestCount() >= 0, true)
}

// === Result Tests ===

@Test
func testResult_success() {
    let result: Result<Int64> = Result.Success(42)
    @Expect(result.isSuccess(), true)
    @Expect(result.isFailure(), false)
}

@Test
func testResult_failure() {
    let result: Result<Int64> = Result.Failure(Exception("error"))
    @Expect(result.isSuccess(), false)
    @Expect(result.isFailure(), true)
}

@Test
func testResult_get() {
    let result: Result<String> = Result.Success("hello")
    let value = result.get()
    @Expect(value, "hello")
}

@Test
func testResult_getOrElse_success() {
    let result: Result<Int64> = Result.Success(100)
    let value = result.getOrElse(0)
    @Expect(value, 100)
}

@Test
func testResult_getOrElse_failure() {
    let result: Result<Int64> = Result.Failure(Exception("error"))
    let value = result.getOrElse(999)
    @Expect(value, 999)
}

@Test
func testResult_nested() {
    let inner: Result<Int64> = Result.Success(50)
    let outer: Result<Result<Int64>> = Result.Success(inner)

    match (outer) {
        case Result.Success(innerResult) =>
            match (innerResult) {
                case Result.Success(value) =>
                    @Expect(value, 50)
                case _ => @Expect(false, true)
            }
        case _ => @Expect(false, true)
    }
}
