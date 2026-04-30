/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - TimerScheduler unit tests
 */
package cactor.runtime.scheduler

import std.collection.*
import std.time.*
import cactor.core.message.*

// Test message class for timer tests.
class TimerTestMessage <: Message {
    public let content: String

    public init(content: String) {
        this.content = content
    }

    public func messageType(): String { "TimerTestMessage" }
}

@Test
func testSimpleTimerScheduler_initialization() {
    let scheduler = SimpleTimerScheduler(Duration.second * 1)
    @Expect(scheduler.isTimerActive("test-key"), false)
}

@Test
func testSimpleTimerScheduler_startSingleTimer() {
    let scheduler = SimpleTimerScheduler(Duration.second * 1)
    let msg: Message = TimerTestMessage("single-timer")
    scheduler.startSingleTimer("single-key", msg, Duration.second * 5)
    @Expect(scheduler.isTimerActive("single-key"), true)
}

@Test
func testSimpleTimerScheduler_startPeriodicTimer() {
    let scheduler = SimpleTimerScheduler(Duration.second * 1)
    let msg: Message = TimerTestMessage("periodic-timer")
    scheduler.startPeriodicTimer("periodic-key", msg, Duration.second * 3)
    @Expect(scheduler.isTimerActive("periodic-key"), true)
}

@Test
func testSimpleTimerScheduler_cancelTimer() {
    let scheduler = SimpleTimerScheduler(Duration.second * 1)
    let msg: Message = TimerTestMessage("cancel-timer")
    scheduler.startSingleTimer("cancel-key", msg, Duration.second * 5)
    @Expect(scheduler.isTimerActive("cancel-key"), true)

    let result = scheduler.cancelTimer("cancel-key")
    @Expect(result, true)
    @Expect(scheduler.isTimerActive("cancel-key"), false)
}

@Test
func testSimpleTimerScheduler_cancelNonExistentTimer() {
    let scheduler = SimpleTimerScheduler(Duration.second * 1)
    let result = scheduler.cancelTimer("non-existent-key")
    @Expect(result, false)
}

@Test
func testSimpleTimerScheduler_cancelAll() {
    let scheduler = SimpleTimerScheduler(Duration.second * 1)
    let msg1: Message = TimerTestMessage("msg1")
    let msg2: Message = TimerTestMessage("msg2")
    let msg3: Message = TimerTestMessage("msg3")
    scheduler.startSingleTimer("key1", msg1, Duration.second * 1)
    scheduler.startSingleTimer("key2", msg2, Duration.second * 2)
    scheduler.startPeriodicTimer("key3", msg3, Duration.second * 3)

    @Expect(scheduler.isTimerActive("key1"), true)
    @Expect(scheduler.isTimerActive("key2"), true)
    @Expect(scheduler.isTimerActive("key3"), true)

    scheduler.cancelAll()

    @Expect(scheduler.isTimerActive("key1"), false)
    @Expect(scheduler.isTimerActive("key2"), false)
    @Expect(scheduler.isTimerActive("key3"), false)
}

@Test
func testSimpleTimerScheduler_checkAndFire_singleTimer() {
    let scheduler = SimpleTimerScheduler(Duration.second * 1)
    let msg: Message = TimerTestMessage("fire-single")
    scheduler.startSingleTimer("fire-key", msg, Duration.second * 0)

    let fired = scheduler.checkAndFire()
    @Expect(fired.size, 1)
    @Expect(scheduler.isTimerActive("fire-key"), false)
}

@Test
func testSimpleTimerScheduler_checkAndFire_periodicTimer() {
    let scheduler = SimpleTimerScheduler(Duration.second * 1)
    let msg: Message = TimerTestMessage("fire-periodic")
    scheduler.startPeriodicTimer("periodic-fire-key", msg, Duration.second * 0)

    let fired = scheduler.checkAndFire()
    @Expect(fired.size, 1)
    @Expect(scheduler.isTimerActive("periodic-fire-key"), true)
}

@Test
func testSimpleTimerScheduler_checkAndFire_multipleTimers() {
    let scheduler = SimpleTimerScheduler(Duration.second * 1)
    let msg1: Message = TimerTestMessage("msg1")
    let msg2: Message = TimerTestMessage("msg2")
    let msg3: Message = TimerTestMessage("msg3")
    scheduler.startSingleTimer("key1", msg1, Duration.second * 0)
    scheduler.startSingleTimer("key2", msg2, Duration.second * 0)
    scheduler.startPeriodicTimer("key3", msg3, Duration.second * 0)

    let fired = scheduler.checkAndFire()
    @Expect(fired.size, 3)
}

@Test
func testSimpleTimerScheduler_checkAndFire_noExpiredTimers() {
    let scheduler = SimpleTimerScheduler(Duration.second * 1)
    let msg: Message = TimerTestMessage("future")
    scheduler.startSingleTimer("future-key", msg, Duration.second * 100)

    let fired = scheduler.checkAndFire()
    @Expect(fired.size, 0)
    @Expect(scheduler.isTimerActive("future-key"), true)
}

@Test
func testTimerTask_properties() {
    let msg: Message = TimerTestMessage("task-test")
    let task = TimerTask("task-key", msg, 5000, true, 1000)
    @Expect(task.key, "task-key")
    @Expect(task.intervalMs, 5000)
    @Expect(task.isPeriodic, true)
    @Expect(task.nextExecutionTime, 6000)
}

@Test
func testTimerTask_singleExecution() {
    let msg: Message = TimerTestMessage("single")
    let task = TimerTask("single-key", msg, 1000, false, 500)
    @Expect(task.key, "single-key")
    @Expect(task.isPeriodic, false)
    @Expect(task.intervalMs, 1000)
    @Expect(task.nextExecutionTime, 1500)
}

@Test
func testReceiveTimeoutMessage_type() {
    let msg = ReceiveTimeoutMessage()
    @Expect(msg.messageType(), "ReceiveTimeout")
}

@Test
func testStartSingleTimer_message() {
    let innerMsg: Message = TimerTestMessage("start-single")
    let startMsg = StartSingleTimer("start-key", innerMsg, Duration.second * 5)
    @Expect(startMsg.key, "start-key")
    @Expect(startMsg.messageType(), "StartSingleTimer")
}

@Test
func testStartPeriodicTimer_message() {
    let innerMsg: Message = TimerTestMessage("start-periodic")
    let startMsg = StartPeriodicTimer("periodic-start-key", innerMsg, Duration.second * 3)
    @Expect(startMsg.key, "periodic-start-key")
    @Expect(startMsg.messageType(), "StartPeriodicTimer")
}

@Test
func testCancelTimer_message() {
    let cancelMsg = CancelTimer("cancel-timer-key")
    @Expect(cancelMsg.key, "cancel-timer-key")
    @Expect(cancelMsg.messageType(), "CancelTimer")
}

@Test
func testCancelAllTimers_message() {
    let cancelAllMsg = CancelAllTimers()
    @Expect(cancelAllMsg.messageType(), "CancelAllTimers")
}

@Test
func testIsTimerActive_message() {
    let isActiveMsg = IsTimerActive("is-active-key")
    @Expect(isActiveMsg.key, "is-active-key")
    @Expect(isActiveMsg.messageType(), "IsTimerActive")
}

@Test
func testTimerTick_message() {
    let tick = TimerTick()
    @Expect(tick.messageType(), "TimerTick")
}

@Test
func testGetCurrentTimeMs() {
    let time1 = getCurrentTimeMs()
    let time2 = getCurrentTimeMs()
    @Expect(time2 >= time1, true)
}
