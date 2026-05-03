/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Pipe Pattern 单元测试
 */
package cactor.patterns.pipe

import std.collection.*
import cactor.core.message.Message
import cactor.core.actor.ActorRef

// === SimpleRef - 测试用可变引用 ===
class SimpleRef<T> {
    private var value: T

    public init(value: T) {
        this.value = value
    }

    public func get(): T {
        value
    }

    public func set(v: T): Unit {
        value = v
    }
}

// === PipeMessage Tests ===

@Test
func testPipeMessage_success() {
    let msg = PipeMessage.success("test value")

    @Expect(msg.isSuccess, true)
    @Expect(msg.value, "test value")
    @Expect(msg.error, "")
}

@Test
func testPipeMessage_failure() {
    let msg = PipeMessage.failure("error occurred")

    @Expect(msg.isSuccess, false)
    @Expect(msg.value, "")
    @Expect(msg.error, "error occurred")
}

// === PipeContext Tests ===

@Test
func testPipeContext_creation() {
    let context = PipeContext()

    match (context.originalMessage) {
        case None => @Expect(true, true)
        case Some(_) => @Expect(false, true)
    }
    match (context.sender) {
        case None => @Expect(true, true)
        case Some(_) => @Expect(false, true)
    }
}

// === PipeBuilder Tests ===

@Test
func testPipeBuilder_onSuccess() {
    let builder = PipeBuilder()
    let called = SimpleRef(false)
    let receivedValue = SimpleRef("")

    builder.onSuccess({ value, ctx =>
        called.set(true)
        receivedValue.set(value)
    })

    builder.executeSuccess("test value")

    @Expect(called.get(), true)
    @Expect(receivedValue.get(), "test value")
}

@Test
func testPipeBuilder_onFailure() {
    let builder = PipeBuilder()
    let called = SimpleRef(false)
    let receivedReason = SimpleRef("")

    builder.onFailure({ reason, ctx =>
        called.set(true)
        receivedReason.set(reason)
    })

    builder.executeFailure("failure reason")

    @Expect(called.get(), true)
    @Expect(receivedReason.get(), "failure reason")
}

@Test
func testPipeBuilder_chaining() {
    let successCalled = SimpleRef(false)

    let builder = PipeBuilder()
        .onSuccess({ v, c => successCalled.set(true) })

    builder.executeSuccess("value")

    @Expect(successCalled.get(), true)
}

// === SuccessMessage Tests ===

@Test
func testSuccessMessage_creation() {
    let msg = SuccessMessage("hello")

    @Expect(msg.value, "hello")
    match (msg.context) {
        case None => @Expect(true, true)
        case Some(_) => @Expect(false, true)
    }
}

// === FailureMessage Tests ===

@Test
func testFailureMessage_creation() {
    let msg = FailureMessage("error occurred")

    @Expect(msg.reason, "error occurred")
    match (msg.context) {
        case None => @Expect(true, true)
        case Some(_) => @Expect(false, true)
    }
}

// === Integration Tests ===

@Test
func testPipe_successCase() {
    let resultProcessed = SimpleRef(false)
    let builder = PipeBuilder()

    builder.onSuccess({ value, ctx =>
        resultProcessed.set(true)
    })

    builder.executeSuccess("processed")

    @Expect(resultProcessed.get(), true)
}

@Test
func testPipe_failureCase() {
    let failureHandled = SimpleRef(false)
    let builder = PipeBuilder()

    builder.onFailure({ reason, ctx =>
        failureHandled.set(true)
    })

    builder.executeFailure("error")

    @Expect(failureHandled.get(), true)
}

@Test
func testPipe_multipleHandlers() {
    let successCount = SimpleRef(0)
    let failureCount = SimpleRef(0)

    let builder = PipeBuilder()

    builder.onSuccess({ v, c =>
        successCount.set(successCount.get() + 1)
    })

    builder.onFailure({ r, ctx =>
        failureCount.set(failureCount.get() + 1)
    })

    builder.executeSuccess("v1")
    builder.executeSuccess("v2")
    builder.executeFailure("e1")

    @Expect(successCount.get(), 2)
    @Expect(failureCount.get(), 1)
}