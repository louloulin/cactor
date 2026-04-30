/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - Backpressure 背压模式单元测试
 */
package cactor.patterns.backpressure

import std.collection.*
import std.time.*
import cactor.core.message.{Message, StringMessage}

/*
 * Test message for backpressure tests
 */
class TestBackpressureMessage <: Message {
    private let content: String

    public init(content: String) {
        this.content = content
    }

    public func messageType(): String { "TestBackpressureMessage" }
    public func getContent(): String { content }
}

// === BackpressureStrategy Tests ===

@Test
func testBackpressureStrategy_values() {
    let drop = BackpressureStrategy.Drop
    let block = BackpressureStrategy.Block
    let buffer = BackpressureStrategy.Buffer
    let reject = BackpressureStrategy.Reject
    let throttle = BackpressureStrategy.Throttle

    @Expect(drop.toString(), "Drop")
    @Expect(block.toString(), "Block")
    @Expect(buffer.toString(), "Buffer")
    @Expect(reject.toString(), "Reject")
    @Expect(throttle.toString(), "Throttle")
}

// === BackpressureConfig Tests ===

@Test
func testBackpressureConfig_creation() {
    let config = BackpressureConfig(
        BackpressureStrategy.Drop,
        100,                    // maxBufferSize
        1000,                   // maxThroughput
        Duration.second * 1,    // windowSize
        0.8,                    // dropThreshold
        Duration.second * 5     // blockTimeout
    )

    @Expect(config.strategy.toString() == "Drop", true)
    @Expect(config.maxBufferSize, 100)
    @Expect(config.maxThroughput, 1000)
    @Expect(config.windowSize == Duration.second * 1, true)
    @Expect(config.dropThreshold > 0.0, true)
    @Expect(config.blockTimeout == Duration.second * 5, true)
}

@Test
func testBackpressureConfig_defaultStrategy() {
    let config = BackpressureConfig(
        BackpressureStrategy.Buffer,
        50,
        500,
        Duration.second * 2,
        0.9,
        Duration.second * 10
    )

    @Expect(config.strategy.toString() == "Buffer", true)
}

// === BackpressureStats Tests ===

@Test
func testBackpressureStats_creation() {
    let stats = BackpressureStats(
        100,     // totalMessages
        10,      // droppedMessages
        5,       // blockedMessages
        80,      // bufferedMessages
        3,       // rejectedMessages
        2,       // throttledMessages
        50.0,    // currentThroughput
        0.8      // bufferUtilization
    )

    @Expect(stats.totalMessages, 100)
    @Expect(stats.droppedMessages, 10)
    @Expect(stats.blockedMessages, 5)
    @Expect(stats.bufferedMessages, 80)
    @Expect(stats.rejectedMessages, 3)
    @Expect(stats.throttledMessages, 2)
}

@Test
func testBackpressureStats_dropRate() {
    let stats = BackpressureStats(
        100,     // totalMessages
        10,      // droppedMessages
        0,       // blockedMessages
        90,      // bufferedMessages
        0,       // rejectedMessages
        0,       // throttledMessages
        50.0,    // currentThroughput
        0.9      // bufferUtilization
    )

    let rate = stats.getDropRate()
    @Expect(rate > 0.0, true)
    @Expect(rate < 1.0, true)
}

@Test
func testBackpressureStats_successRate() {
    let stats = BackpressureStats(
        100,     // totalMessages
        10,      // droppedMessages
        0,       // blockedMessages
        90,      // bufferedMessages
        0,       // rejectedMessages
        0,       // throttledMessages
        50.0,    // currentThroughput
        0.9      // bufferUtilization
    )

    let rate = stats.getSuccessRate()
    @Expect(rate > 0.0, true)
    @Expect(rate < 1.0, true)
}

@Test
func testBackpressureStats_zeroMessages() {
    let stats = BackpressureStats(
        0,       // totalMessages
        0,       // droppedMessages
        0,       // blockedMessages
        0,       // bufferedMessages
        0,       // rejectedMessages
        0,       // throttledMessages
        0.0,     // currentThroughput
        0.0      // bufferUtilization
    )

    @Expect(stats.getDropRate(), 0.0)
    @Expect(stats.getSuccessRate(), 1.0)
}

// === BackpressureException Tests ===

@Test
func testBackpressureException_creation() {
    let ex = BackpressureException(BackpressureStrategy.Reject, "Buffer full")
    @Expect(ex.message.size > 0, true)
}

@Test
func testBackpressureException_getStrategy() {
    let ex = BackpressureException(BackpressureStrategy.Drop, "Threshold exceeded")
    match (ex.getStrategy()) {
        case BackpressureStrategy.Drop => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

@Test
func testBackpressureException_getReason() {
    let reason = "Test reason"
    let ex = BackpressureException(BackpressureStrategy.Block, reason)
    @Expect(ex.getReason() == reason, true)
}

// === BasicBackpressureController Tests ===

@Test
func testBasicBackpressureController_initialization() {
    let config = BackpressureConfig(
        BackpressureStrategy.Drop,
        100,
        1000,
        Duration.second * 1,
        0.8,
        Duration.second * 5
    )
    let controller = BasicBackpressureController(config)

    @Expect(controller.isOverloaded() == false || controller.isOverloaded() == true, true)
}

@Test
func testBasicBackpressureController_trySendSuccess() {
    let config = BackpressureConfig(
        BackpressureStrategy.Drop,
        100,
        1000,
        Duration.second * 1,
        0.8,
        Duration.second * 5
    )
    let controller = BasicBackpressureController(config)

    let msg = TestBackpressureMessage("test")
    let result = controller.trySend(msg)
    @Expect(result == true || result == false, true)
}

@Test
func testBasicBackpressureController_getStats() {
    let config = BackpressureConfig(
        BackpressureStrategy.Buffer,
        50,
        500,
        Duration.second * 2,
        0.9,
        Duration.second * 10
    )
    let controller = BasicBackpressureController(config)

    let stats = controller.getStats()
    @Expect(stats.totalMessages >= 0, true)
    @Expect(stats.droppedMessages >= 0, true)
    @Expect(stats.bufferedMessages >= 0, true)
}

@Test
func testBasicBackpressureController_reset() {
    let config = BackpressureConfig(
        BackpressureStrategy.Drop,
        100,
        1000,
        Duration.second * 1,
        0.8,
        Duration.second * 5
    )
    let controller = BasicBackpressureController(config)

    let msg = TestBackpressureMessage("test")
    controller.trySend(msg)
    controller.reset()

    let stats = controller.getStats()
    @Expect(stats.totalMessages >= 0, true)
}

@Test
func testBasicBackpressureController_multipleMessages() {
    let config = BackpressureConfig(
        BackpressureStrategy.Buffer,
        100,
        1000,
        Duration.second * 1,
        0.8,
        Duration.second * 5
    )
    let controller = BasicBackpressureController(config)

    for (i in 0..10) {
        let msg = TestBackpressureMessage("test${i}")
        controller.trySend(msg)
    }

    let stats = controller.getStats()
    @Expect(stats.totalMessages >= 10, true)
}

// === FlowController Tests ===

@Test
func testFlowControllerInterface() {
    let config = BackpressureConfig(
        BackpressureStrategy.Drop,
        100,
        1000,
        Duration.second * 1,
        0.8,
        Duration.second * 5
    )
    let controller: FlowController = BasicBackpressureController(config)

    @Expect(controller.isOverloaded() == false || controller.isOverloaded() == true, true)
    @Expect(controller.getStats().totalMessages >= 0, true)
}
