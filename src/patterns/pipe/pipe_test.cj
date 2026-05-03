/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Pipe Pattern 单元测试
 */
package cactor.patterns.pipe

import std.collection.*
import std.sync.*
import cactor.core.message.Message
import cactor.core.actor.ActorRef

// Ref type alias
typealias Ref<T> = std.sync.Ref<T>

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
    let called = Ref(false)
    let receivedValue = Ref("")

    builder.onSuccess({ value, ctx =>
        called.store(true)
        receivedValue.store(value)
    })

    builder.executeSuccess("test value")

    @Expect(called.load(), true)
    @Expect(receivedValue.load(), "test value")
}

@Test
func testPipeBuilder_onFailure() {
    let builder = PipeBuilder()
    let called = Ref(false)
    let receivedReason = Ref("")

    builder.onFailure({ reason, ctx =>
        called.store(true)
        receivedReason.store(reason)
    })

    builder.executeFailure("failure reason")

    @Expect(called.load(), true)
    @Expect(receivedReason.load(), "failure reason")
}

@Test
func testPipeBuilder_chaining() {
    let successCalled = Ref(false)

    let builder = PipeBuilder()
        .onSuccess({ v, c => successCalled.store(true) })

    builder.executeSuccess("value")

    @Expect(successCalled.load(), true)
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
    let resultProcessed = Ref(false)
    let builder = PipeBuilder()

    builder.onSuccess({ value, ctx =>
        resultProcessed.store(true)
    })

    builder.executeSuccess("processed")

    @Expect(resultProcessed.load(), true)
}

@Test
func testPipe_failureCase() {
    let failureHandled = Ref(false)
    let builder = PipeBuilder()

    builder.onFailure({ reason, ctx =>
        failureHandled.store(true)
    })

    builder.executeFailure("error")

    @Expect(failureHandled.load(), true)
}

@Test
func testPipe_multipleHandlers() {
    let successCount = Ref(0)
    let failureCount = Ref(0)

    let builder = PipeBuilder()

    builder.onSuccess({ v, c =>
        successCount.store(successCount.load() + 1)
    })

    builder.onFailure({ r, ctx =>
        failureCount.store(failureCount.load() + 1)
    })

    builder.executeSuccess("v1")
    builder.executeSuccess("v2")
    builder.executeFailure("e1")

    @Expect(successCount.load(), 2)
    @Expect(failureCount.load(), 1)
}
